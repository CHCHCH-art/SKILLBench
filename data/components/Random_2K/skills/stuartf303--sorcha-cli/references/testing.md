# CLI Testing Reference

## Test Project Location

```
tests/Sorcha.Cli.Tests/
├── Commands/           # Command structure tests
├── Services/           # Service tests
└── Infrastructure/     # Helper tests
```

## System.CommandLine Option Name Issue

### The Problem

In System.CommandLine 2.0.2, the `Option.Name` property returns the **full alias including dashes**, not just the name part.

```csharp
var option = new Option<string>("--id", "Description");
// option.Name == "--id"  (NOT "id")
// option.Aliases contains "--id"
```

### Wrong Test Pattern (Fails)

```csharp
[Fact]
public void Command_ShouldHaveRequiredIdOption()
{
    var command = new MyCommand(...);
    // This FAILS because Name is "--id" not "id"
    var idOption = command.Options.FirstOrDefault(o => o.Name == "id");
    idOption.Should().NotBeNull();
}
```

### Correct Test Pattern (Use Name == with dashes)

**IMPORTANT:** The `Aliases` collection does NOT automatically include the option name.
Use `o.Name == "--id"` to find options by name.

```csharp
[Fact]
public void Command_ShouldHaveRequiredIdOption()
{
    var command = new MyCommand(...);
    // CORRECT: Use Name property with full option name including dashes
    var idOption = command.Options.FirstOrDefault(o => o.Name == "--id");
    idOption.Should().NotBeNull();
    idOption!.Required.Should().BeTrue();
}
```

### WRONG Patterns (These will fail!)

```csharp
// WRONG: Name without dashes
var idOption = command.Options.FirstOrDefault(o => o.Name == "id");

// WRONG: Aliases.Contains - Aliases doesn't include the primary name
var idOption = command.Options.FirstOrDefault(o => o.Aliases.Contains("--id"));
```

## Test Setup Pattern

```csharp
public class MyCommandTests
{
    private readonly Mock<IAuthenticationService> _mockAuthService;
    private readonly Mock<IConfigurationService> _mockConfigService;
    private readonly HttpClientFactory _clientFactory;

    public MyCommandTests()
    {
        _mockAuthService = new Mock<IAuthenticationService>();
        _mockConfigService = new Mock<IConfigurationService>();

        // Setup default mock behavior
        _mockConfigService.Setup(x => x.GetActiveProfileAsync())
            .ReturnsAsync(new Profile { Name = "test" });
        _mockAuthService.Setup(x => x.GetAccessTokenAsync(It.IsAny<string>()))
            .ReturnsAsync("test-token");

        _clientFactory = new HttpClientFactory(_mockConfigService.Object);
    }

    private IAuthenticationService AuthService => _mockAuthService.Object;
    private IConfigurationService ConfigService => _mockConfigService.Object;
}
```

## Command Structure Tests

### Test Command Name and Description

```csharp
[Fact]
public void MyCommand_ShouldHaveCorrectNameAndDescription()
{
    var command = new MyCommand(_clientFactory, AuthService, ConfigService);
    command.Name.Should().Be("mycommand");
    command.Description.Should().NotBeNullOrWhiteSpace();
}
```

### Test Subcommand Count

```csharp
[Fact]
public void ParentCommand_ShouldHaveExpectedSubcommands()
{
    var command = new ParentCommand(_clientFactory, AuthService, ConfigService);
    command.Subcommands.Should().HaveCount(4);
    command.Subcommands.Select(c => c.Name)
        .Should().Contain(new[] { "list", "get", "create", "delete" });
}
```

### Test Required Option

```csharp
[Fact]
public void Command_ShouldHaveRequiredIdOption()
{
    var command = new MyCommand(_clientFactory, AuthService, ConfigService);
    var idOption = command.Options.FirstOrDefault(o => o.Name == "--id");
    idOption.Should().NotBeNull();
    idOption!.Required.Should().BeTrue();
}
```

### Test Optional Option

```csharp
[Fact]
public void Command_ShouldHaveOptionalPageOption()
{
    var command = new MyCommand(_clientFactory, AuthService, ConfigService);
    var pageOption = command.Options.FirstOrDefault(o => o.Name == "--page");
    pageOption.Should().NotBeNull();
    pageOption!.Required.Should().BeFalse();
}
```

## Mocking Refit Clients

```csharp
[Fact]
public async Task Command_ShouldReturnSuccess_WhenApiSucceeds()
{
    // Arrange
    var mockClient = new Mock<IMyServiceClient>();
    mockClient.Setup(x => x.GetAsync(It.IsAny<string>(), It.IsAny<string>()))
        .ReturnsAsync(new Resource { Id = "test-id", Name = "Test" });

    // Mock the factory to return our mock client
    var mockFactory = new Mock<HttpClientFactory>(_mockConfigService.Object);
    mockFactory.Setup(x => x.CreateMyServiceClientAsync(It.IsAny<string>()))
        .ReturnsAsync(mockClient.Object);

    // Act & Assert
    // ... command execution
}
```

## Testing Error Handling

```csharp
[Fact]
public async Task Command_ShouldReturnNotFound_WhenResourceNotFound()
{
    // Arrange
    var mockClient = new Mock<IMyServiceClient>();
    mockClient.Setup(x => x.GetAsync(It.IsAny<string>(), It.IsAny<string>()))
        .ThrowsAsync(ApiException.Create(
            new HttpRequestMessage(),
            HttpMethod.Get,
            new HttpResponseMessage(HttpStatusCode.NotFound),
            new RefitSettings()));

    // Act & Assert
    // ... command execution should return ExitCodes.NotFound
}
```

## Command Execution Tests

```csharp
[Fact]
public async Task Command_ShouldParseArguments_Correctly()
{
    var rootCommand = new RootCommand();
    rootCommand.Subcommands.Add(new MyCommand(_clientFactory, AuthService, ConfigService));

    var parseResult = rootCommand.Parse("mycommand --id test-123 --verbose");

    parseResult.Errors.Should().BeEmpty();
}
```

## Test Data Builders

```csharp
public static class TestDataBuilders
{
    public static Register CreateRegister(
        string? id = null,
        string? name = null,
        string? status = null)
    {
        return new Register
        {
            Id = id ?? Guid.NewGuid().ToString(),
            Name = name ?? "Test Register",
            Status = status ?? "Online",
            Height = 1,
            TenantId = Guid.NewGuid().ToString(),
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
    }

    public static TransactionModel CreateTransaction(
        string? txId = null,
        string? registerId = null)
    {
        return new TransactionModel
        {
            TxId = txId ?? Guid.NewGuid().ToString(),
            RegisterId = registerId ?? Guid.NewGuid().ToString(),
            Version = 1,
            SenderWallet = "wallet-address",
            TimeStamp = DateTimeOffset.UtcNow,
            Signature = "signature",
            Payloads = Array.Empty<PayloadModel>()
        };
    }
}
```

## Common Test Assertions

```csharp
// Command has correct options (use Name == with dashes)
command.Options.Should().Contain(o => o.Name == "--id");

// Subcommand count
command.Subcommands.Should().HaveCount(3);

// Exit code
exitCode.Should().Be(ExitCodes.Success);

// Option properties
option.Required.Should().BeTrue();
option.Description.Should().NotBeNullOrWhiteSpace();
```
