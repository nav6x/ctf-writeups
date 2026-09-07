using System.Text.Json;
using MetadataExtractor;
using MetadataExtractor.Formats.Exif;

static class Exif
{
    public static (object Location, double X, double Y)? ReadLocation(Stream photo)
    {
        var metadata = ImageMetadataReader.ReadMetadata(photo);

        var comment = metadata.OfType<ExifSubIfdDirectory>()
            .Select(directory => directory.GetDescription(ExifDirectoryBase.TagUserComment))
            .FirstOrDefault(value => value is not null);

        if (comment is not null && ReadTags(comment) is { } tags
            && tags.TryGetValue("location", out var tagged)
            && tagged.ValueKind == JsonValueKind.Object
            && tagged.TryGetProperty("x", out var x) && x.ValueKind == JsonValueKind.Number
            && tagged.TryGetProperty("y", out var y) && y.ValueKind == JsonValueKind.Number)
            return (tagged, x.GetDouble(), y.GetDouble());

        if (metadata.OfType<GpsDirectory>().FirstOrDefault()?.GetGeoLocation() is not { } gps)
            return null;

        return (Tuple.Create(gps.Longitude, gps.Latitude), gps.Longitude, gps.Latitude);
    }

    private static Dictionary<string, JsonElement>? ReadTags(string comment)
    {
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(comment);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
