using System.Text;
using ClickHouse.Driver;
using MetadataExtractor;

const int BucketSize = 100;
const int ClassificationBytes = 100;
const long FlagAt = 1_000_000;

var flag = Environment.GetEnvironmentVariable("FLAG") ?? "NNS{test_flag}";
var client = new ClickHouseClient(
    Environment.GetEnvironmentVariable("CLICKHOUSE_URL")
    ?? "Host=clickhouse;Port=8123;Username=default;Database=default");
var classifier = new HttpClient
{
    BaseAddress = new Uri(
        Environment.GetEnvironmentVariable("CLASSIFIER_URL") ?? "http://beer-classifier:8000"),
    Timeout = TimeSpan.FromMinutes(2),
};

for (var attempt = 0; ; attempt++)
{
    try
    {
        await client.ExecuteNonQueryAsync("""
            CREATE TABLE IF NOT EXISTS beers (
                location Point,
                amount UInt32,
                classification String,
                approved Bool
            ) ENGINE = MergeTree ORDER BY tuple()
            """);
        break;
    }
    catch (Exception) when (attempt < 60)
    {
        await Task.Delay(1000);
    }
}

var columns = new[] { "location", "amount", "classification", "approved" };
var police = new object();
var tokens = (double)BucketSize;
var refilled = DateTime.UtcNow;

string Fit(string classification)
{
    Span<byte> buffer = stackalloc byte[ClassificationBytes];
    Encoding.UTF8.GetEncoder().Convert(classification, buffer, true, out _, out var written, out _);
    return Encoding.UTF8.GetString(buffer[..written]);
}

bool Approve()
{
    lock (police)
    {
        var now = DateTime.UtcNow;
        tokens = Math.Min(BucketSize, tokens + (now - refilled).TotalHours * BucketSize);
        refilled = now;
        if (tokens < 1)
            return false;
        tokens -= 1;
        return true;
    }
}

var app = WebApplication.CreateBuilder(args).Build();

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapPost("/api/beers", async (IFormFile photo) =>
{
    (object Location, double X, double Y)? found;
    using (var stream = photo.OpenReadStream())
    {
        try
        {
            found = Exif.ReadLocation(stream);
        }
        catch (Exception exception) when (exception is ImageProcessingException or IOException)
        {
            return Results.BadRequest(new { error = "that is not a photo" });
        }
    }

    if (found is null)
        return Results.BadRequest(new { error = "the photo does not say where it was taken" });

    var (location, x, y) = found.Value;
    if (!double.IsFinite(x) || !double.IsFinite(y) || Math.Abs(x) > 180 || Math.Abs(y) > 90)
        return Results.BadRequest(new { error = "the beer must be somewhere on earth" });

    using var content = new MultipartFormDataContent();
    content.Add(new StreamContent(photo.OpenReadStream()), "photo", "photo.jpg");
    var looked = await classifier.PostAsync("/classify", content);
    if (!looked.IsSuccessStatusCode)
        return Results.BadRequest(new { error = "that is not a photo" });

    var classification = Fit(Encoding.UTF8.GetString(await looked.Content.ReadAsByteArrayAsync()));
    if (classification.Trim() == "no")
        return Results.BadRequest(new { error = "the beer police see no beer" });

    var approved = Approve();
    var rows = new[] { new object[] { location, 1u, classification, approved } };
    var inserted = await client.InsertBinaryAsync("beers", columns, rows);

    return Results.Ok(new { inserted, approved, classification });
}).DisableAntiforgery();

app.MapGet("/api/stats", async () =>
{
    long counted, approved, rejected;
    using (var totals = await client.ExecuteReaderAsync("""
        SELECT toInt64(sumIf(amount, approved)), toInt64(countIf(approved)), toInt64(countIf(NOT approved))
        FROM beers
        """))
    {
        await totals.ReadAsync();
        counted = totals.GetInt64(0);
        approved = totals.GetInt64(1);
        rejected = totals.GetInt64(2);
    }

    var map = new List<object>();
    using (var places = await client.ExecuteReaderAsync("""
        SELECT round(location.1, 2), round(location.2, 2), toInt64(count())
        FROM beers
        WHERE approved
        GROUP BY 1, 2
        ORDER BY 3 DESC
        LIMIT 200
        """))
    {
        while (await places.ReadAsync())
            map.Add(new { x = places.GetDouble(0), y = places.GetDouble(1), beers = places.GetInt64(2) });
    }

    return Results.Ok(new
    {
        counted,
        goal = FlagAt,
        approved,
        rejected,
        map,
        flag = counted >= FlagAt ? flag : null,
    });
});

app.Run();
