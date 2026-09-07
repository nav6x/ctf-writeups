using System.Text.Json;
using ClickHouse.Driver;

var client = new ClickHouseClient("Host=clickhouse;Port=8123;Username=default;Database=default");
await client.ExecuteNonQueryAsync("TRUNCATE TABLE beers");

var comment = "{\"location\":{\"x\":0.0,\"y\":0.0}}";
var doc = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(comment)!;
var tagged = doc["location"];

var classification = "this is a beer  cold golden lager brew tasty yum";
var columns = new[] { "location", "amount", "classification", "approved" };
object location = tagged;
var rows = new[] { new object[] { location, 1u, classification, true } };

var inserted = await client.InsertBinaryAsync("beers", columns, rows);
Console.WriteLine($"inserted={inserted}");

using var r = await client.ExecuteReaderAsync(
    "SELECT toInt64(sumIf(amount, approved)), toInt64(count()), any(classification) FROM beers");
await r.ReadAsync();
Console.WriteLine($"counted={r.GetInt64(0)} rows={r.GetInt64(1)} stored_classification={r.GetString(2)}");
Console.WriteLine(r.GetInt64(0) >= 1_000_000 ? "RESULT: DESYNC CONFIRMED (>=1e6)" : "RESULT: no desync");
