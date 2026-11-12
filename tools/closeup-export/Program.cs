using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets.Exports.Texture;
using CUE4Parse.UE4.Versions;
using CUE4Parse_Conversion.Textures;
using SkiaSharp;
using System.Security.Cryptography;
using System.Text.Json;

// Inputs and all outputs are private local artifacts. Never launch the game.
var requests = JsonSerializer.Deserialize<List<Request>>(File.ReadAllText(args[1]))!;
var provider = new DefaultFileProvider(args[0], SearchOption.TopDirectoryOnly, true,
    new VersionContainer(EGame.GAME_UE4_23));
provider.Initialize();
provider.Mount();
using var results = new StreamWriter(args[2]);
foreach (var request in requests)
{
    var row = new Dictionary<string, object?> { ["member"] = request.member };
    try
    {
        var package = provider.LoadPackage(request.member);
        var exports = package.GetExports().ToArray();
        row["exports"] = exports.Select(x => new { name = x.Name, type = x.GetType().Name }).ToArray();
        if (request.inspect)
        {
            File.WriteAllText(request.output, Newtonsoft.Json.JsonConvert.SerializeObject(exports,
                Newtonsoft.Json.Formatting.Indented));
            row["status"] = "inspected";
        }
        else
        {
            var textures = exports.OfType<UTexture2D>().ToArray();
            if (textures.Length == 0) row["status"] = "not_texture";
            else if (textures.Length != 1) throw new InvalidDataException("Expected exactly one Texture2D export");
            else
            {
                var texture = textures[0];
                row["object_name"] = texture.Name;
                var image = texture.Decode();
                using var bitmap = image.ToSkBitmap();
                using var png = bitmap.Encode(SKEncodedImageFormat.Png, 100);
                var bytes = png.ToArray();
                File.WriteAllBytes(request.output, bytes);
                row["status"] = "decoded";
                row["width"] = image.Width;
                row["height"] = image.Height;
                row["pixel_format"] = image.PixelFormat.ToString();
                row["png_sha256"] = Convert.ToHexStringLower(SHA256.HashData(bytes));
                row["png_bytes"] = bytes.Length;
            }
        }
    }
    catch (Exception error)
    {
        row["status"] = "failed";
        row["error"] = error.ToString();
    }
    results.WriteLine(JsonSerializer.Serialize(row));
    results.Flush();
}
record Request(string member, string output, bool inspect);
