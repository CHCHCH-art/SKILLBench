# CLI Commands Reference

## Command Structure

The Sorcha CLI follows a hierarchical command structure:

```
sorcha
├── auth                    # Authentication commands
│   ├── login              # Authenticate with credentials
│   ├── logout             # Clear cached tokens
│   └── status             # Show authentication status
├── config                  # Configuration management
│   ├── profile list       # List profiles
│   ├── profile set        # Set active profile
│   └── profile create     # Create new profile
├── register               # Register (ledger) management
│   ├── list               # List all registers
│   ├── get                # Get register by ID
│   ├── create             # Create new register (two-phase)
│   ├── update             # Update register metadata
│   ├── delete             # Delete register
│   └── stats              # Get register statistics
├── tx                     # Transaction commands
│   ├── list               # List transactions in register
│   ├── get                # Get transaction by ID
│   ├── submit             # Submit new transaction
│   └── status             # Check transaction status
├── docket                 # Docket (block) inspection
│   ├── list               # List dockets in register
│   ├── get                # Get docket by ID
│   └── transactions       # List transactions in docket
├── query                  # Cross-register queries
│   ├── wallet             # Query by wallet address
│   ├── sender             # Query by sender address
│   ├── blueprint          # Query by blueprint ID
│   ├── stats              # Get query statistics
│   └── odata              # Execute OData query
├── wallet                 # Wallet management
│   ├── list               # List wallets
│   ├── get                # Get wallet by address
│   ├── create             # Create new wallet
│   ├── recover            # Recover from mnemonic
│   ├── delete             # Delete wallet
│   └── sign               # Sign data
├── org                    # Organization management
├── user                   # User management
├── sp                     # Service principal management
└── peer                   # Peer network management
```

## Common Option Patterns

### Required Options

```csharp
_idOption = new Option<string>("--id", "Resource ID") { Required = true };
```

### Optional Options with Defaults

```csharp
_pageOption = new Option<int?>("--page", "Page number (default: 1)");
_pageSizeOption = new Option<int?>("--page-size", "Items per page (default: 50)");
```

### Boolean Flags

```csharp
_yesOption = new Option<bool>("--yes", "Skip confirmation prompt");
_verboseOption = new Option<bool>("--verbose", "Enable verbose output");
```

### Nullable Options

```csharp
_descriptionOption = new Option<string?>("--description", "Optional description");
```

## Two-Phase Register Creation Pattern

The register creation uses a cryptographic attestation flow:

```csharp
// Phase 1: Initiate
var initiateRequest = new InitiateRegisterCreationRequest
{
    Name = name,
    TenantId = tenantId,
    Description = description,
    Owners = new List<OwnerInfo>
    {
        new OwnerInfo { UserId = userId, WalletId = ownerWallet }
    }
};
var initiateResponse = await registerClient.InitiateRegisterCreationAsync(
    initiateRequest, $"Bearer {token}");

// Phase 2: Sign attestations
var signedAttestations = new List<SignedAttestation>();
foreach (var attestation in initiateResponse.AttestationsToSign)
{
    var hashBytes = Convert.FromHexString(attestation.DataToSign);
    var base64Hash = Convert.ToBase64String(hashBytes);

    var signRequest = new SignTransactionRequest
    {
        TransactionData = base64Hash,
        IsPreHashed = true
    };

    var signResponse = await walletClient.SignTransactionAsync(
        attestation.WalletId, signRequest, $"Bearer {token}");

    signedAttestations.Add(new SignedAttestation
    {
        AttestationData = attestation.AttestationData,
        PublicKey = signResponse.PublicKey,
        Signature = signResponse.Signature,
        Algorithm = algorithm
    });
}

// Phase 3: Finalize
var finalizeRequest = new FinalizeRegisterCreationRequest
{
    RegisterId = initiateResponse.RegisterId,
    Nonce = initiateResponse.Nonce,
    SignedAttestations = signedAttestations
};
var finalizeResponse = await registerClient.FinalizeRegisterCreationAsync(
    finalizeRequest, $"Bearer {token}");
```

## Pagination Pattern

```csharp
// Options
_pageOption = new Option<int?>("--page", "Page number (default: 1)");
_pageSizeOption = new Option<int?>("--page-size", "Items per page (default: 50)");

// In action handler
var page = parseResult.GetValue(_pageOption);
var pageSize = parseResult.GetValue(_pageSizeOption);

// API call
var results = await client.ListAsync(page, pageSize, $"Bearer {token}");

// Display pagination info
if (page.HasValue || pageSize.HasValue)
{
    Console.WriteLine();
    ConsoleHelper.WriteInfo($"Page {page ?? 1} of {totalPages} (Total: {totalCount})");
}
```

## Table Display Pattern

```csharp
// Header
Console.WriteLine($"{"ID",-36} {"Name",-30} {"Status",-10} {"Created"}");
Console.WriteLine(new string('-', 100));

// Rows
foreach (var item in items)
{
    Console.WriteLine($"{item.Id,-36} {item.Name,-30} {item.Status,-10} {item.CreatedAt:yyyy-MM-dd}");
}
```

## Detail Display Pattern

```csharp
ConsoleHelper.WriteSuccess("Resource details:");
Console.WriteLine();
Console.WriteLine($"  ID:          {resource.Id}");
Console.WriteLine($"  Name:        {resource.Name}");
Console.WriteLine($"  Status:      {resource.Status}");
Console.WriteLine($"  Created:     {resource.CreatedAt:yyyy-MM-dd HH:mm:ss}");

if (!string.IsNullOrEmpty(resource.Description))
{
    Console.WriteLine($"  Description: {resource.Description}");
}
```

## Confirmation Prompt Pattern

```csharp
if (!confirm)
{
    ConsoleHelper.WriteWarning("WARNING: This action cannot be undone.");
    Console.Write($"Are you sure you want to delete '{id}'? [y/N]: ");
    var response = Console.ReadLine()?.Trim().ToLowerInvariant();

    if (response != "y" && response != "yes")
    {
        ConsoleHelper.WriteInfo("Operation cancelled.");
        return ExitCodes.Success;
    }
}
```

## JWT Token Extraction

```csharp
using System.IdentityModel.Tokens.Jwt;

var handler = new JwtSecurityTokenHandler();
var jwtToken = handler.ReadJwtToken(token);
var userId = jwtToken.Claims.FirstOrDefault(c => c.Type == "sub")?.Value
    ?? jwtToken.Claims.FirstOrDefault(c => c.Type == "userId")?.Value
    ?? throw new InvalidOperationException("Could not extract user ID from token");
```
