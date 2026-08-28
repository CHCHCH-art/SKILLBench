# EF Core JSON Column Patterns Reference

## Provider-Specific Configuration

### SQL Server

```csharp
modelBuilder.Entity<ContentItem>(entity =>
{
    entity.OwnsOne(e => e.Extensions, builder =>
    {
        builder.ToJson("ExtensionsJson"); // Explicit column name
    });

    // SQL Server stores as NVARCHAR(MAX) by default
});
```

### PostgreSQL (Npgsql)

```csharp
modelBuilder.Entity<ContentItem>(entity =>
{
    entity.OwnsOne(e => e.Extensions, builder =>
    {
        builder.ToJson();
    });

    // PostgreSQL uses JSONB for efficient querying
    entity.Property(e => e.Extensions)
        .HasColumnType("jsonb");
});
```

### SQLite

```csharp
// SQLite stores JSON as TEXT
// Full JSON querying requires json1 extension
modelBuilder.Entity<ContentItem>(entity =>
{
    entity.OwnsOne(e => e.Extensions, builder =>
    {
        builder.ToJson();
    });
});
```

## Nested Owned Entities

```csharp
public class ContentItem
{
    public Guid Id { get; set; }
    public ContentParts Parts { get; set; } = new();
}

public class ContentParts
{
    public TitlePart? Title { get; set; }
    public AuthorPart? Author { get; set; }
    public List<TagPart> Tags { get; set; } = new();
}

public class AuthorPart
{
    public string Name { get; set; } = string.Empty;
    public ContactInfo? Contact { get; set; }
}

public class ContactInfo
{
    public string? Email { get; set; }
    public string? Twitter { get; set; }
}

// Configuration with nested ownership
modelBuilder.Entity<ContentItem>(entity =>
{
    entity.OwnsOne(e => e.Parts, parts =>
    {
        parts.ToJson();

        parts.OwnsOne(p => p.Title);
        parts.OwnsOne(p => p.Author, author =>
        {
            author.OwnsOne(a => a.Contact);
        });
        parts.OwnsMany(p => p.Tags);
    });
});
```

## Collection Support

### Arrays in JSON

```csharp
public class Article
{
    public Guid Id { get; set; }
    public ArticleData Data { get; set; } = new();
}

public class ArticleData
{
    public List<string> Tags { get; set; } = new();
    public List<RelatedLink> Links { get; set; } = new();
    public string[] Categories { get; set; } = Array.Empty<string>();
}

public class RelatedLink
{
    public string Url { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public int? Order { get; set; }
}

// Configuration
modelBuilder.Entity<Article>(entity =>
{
    entity.OwnsOne(e => e.Data, data =>
    {
        data.ToJson();
        data.OwnsMany(d => d.Links);
    });
});

// Query collection
var articles = await context.Articles
    .Where(a => a.Data.Tags.Contains("csharp"))
    .ToListAsync();
```

## Polymorphic JSON Storage

### Discriminator Pattern

```csharp
public abstract class ContentPart
{
    public string PartType { get; set; } = string.Empty;
}

public class TextPart : ContentPart
{
    public string Text { get; set; } = string.Empty;
}

public class ImagePart : ContentPart
{
    public string Url { get; set; } = string.Empty;
    public string? Alt { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
}

// Custom converter for polymorphic deserialization
public class ContentPartConverter : JsonConverter<ContentPart>
{
    public override ContentPart? Read(ref Utf8JsonReader reader,
        Type typeToConvert, JsonSerializerOptions options)
    {
        using var doc = JsonDocument.ParseValue(ref reader);
        var root = doc.RootElement;

        var partType = root.GetProperty("partType").GetString();

        return partType switch
        {
            "text" => JsonSerializer.Deserialize<TextPart>(
                root.GetRawText(), options),
            "image" => JsonSerializer.Deserialize<ImagePart>(
                root.GetRawText(), options),
            _ => throw new JsonException($"Unknown part type: {partType}")
        };
    }

    public override void Write(Utf8JsonWriter writer,
        ContentPart value, JsonSerializerOptions options)
    {
        JsonSerializer.Serialize(writer, value, value.GetType(), options);
    }
}
```

## Query Optimization

### Projection to Reduce Data Transfer

```csharp
// Project only needed JSON properties
var summaries = await context.Articles
    .Select(a => new ArticleSummary
    {
        Id = a.Id,
        Title = a.Title,
        // Only serialize needed parts
        Tags = a.Data.Tags,
        AuthorName = a.Data.Author!.Name
    })
    .ToListAsync();
```

### Conditional Loading

```csharp
// Load with or without JSON based on need
public async Task<ContentItem?> GetContentAsync(
    Guid id, bool includeExtensions = false)
{
    var query = context.ContentItems.AsQueryable();

    if (includeExtensions)
    {
        return await query
            .FirstOrDefaultAsync(c => c.Id == id);
    }
    else
    {
        // Exclude heavy JSON column
        return await query
            .Select(c => new ContentItem
            {
                Id = c.Id,
                Title = c.Title,
                ContentType = c.ContentType,
                Status = c.Status
                // Extensions not loaded
            })
            .FirstOrDefaultAsync(c => c.Id == id);
    }
}
```

## Migration Strategies

### Adding JSON Column to Existing Table

```csharp
public partial class AddExtensionsJson : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Extensions",
            table: "ContentItems",
            type: "nvarchar(max)",
            nullable: false,
            defaultValue: "{}");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "Extensions",
            table: "ContentItems");
    }
}
```

### Migrating EAV to JSON

```csharp
// Step 1: Add JSON column
migrationBuilder.AddColumn<string>(
    name: "FieldsJson",
    table: "ContentItems",
    type: "nvarchar(max)",
    nullable: true);

// Step 2: Migrate data (run as separate step)
migrationBuilder.Sql(@"
    UPDATE c SET c.FieldsJson = (
        SELECT f.FieldName, f.FieldValue
        FROM ContentFields f
        WHERE f.ContentItemId = c.Id
        FOR JSON PATH
    )
    FROM ContentItems c
");

// Step 3: Drop EAV table (after validation)
migrationBuilder.DropTable(name: "ContentFields");
```

## Testing JSON Columns

### In-Memory Testing

```csharp
// In-memory provider has limited JSON support
// Use SQLite for testing JSON queries
public class ContentDbContextTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly ContentDbContext _context;

    public ContentDbContextTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<ContentDbContext>()
            .UseSqlite(_connection)
            .Options;

        _context = new ContentDbContext(options);
        _context.Database.EnsureCreated();
    }

    [Fact]
    public async Task CanQueryJsonProperties()
    {
        // Arrange
        var item = new ContentItem
        {
            Title = "Test",
            Extensions = new ContentExtensions
            {
                SeoPart = new SeoPartData { MetaTitle = "SEO Title" }
            }
        };
        _context.ContentItems.Add(item);
        await _context.SaveChangesAsync();

        // Act
        var result = await _context.ContentItems
            .FirstOrDefaultAsync(c => c.Extensions.SeoPart!.MetaTitle == "SEO Title");

        // Assert
        Assert.NotNull(result);
    }

    public void Dispose()
    {
        _context.Dispose();
        _connection.Dispose();
    }
}
```
