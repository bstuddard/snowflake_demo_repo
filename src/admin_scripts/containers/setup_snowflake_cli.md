# Snowflake CLI Setup Guide

This guide walks through setting up Snowflake CLI for Container Services image registry authentication.

## Prerequisites

- Snowflake CLI installed (`snow`)
- Private key file (`keys/rsa_key.p8`)
- Private key passphrase (if key is encrypted)

## Step-by-Step Setup

### 1. Install Snowflake CLI

### 2. Create Connection

Run the connection setup command:
```cmd
snow connection add
```

### 3. Connection Configuration Values

When prompted, enter the following:

| Field | Value | Notes |
|-------|-------|-------|
| **Connection name** | `default` | Or any descriptive name |
| **Account** | Your Snowflake account identifier | e.g., `xy12345` or `xy12345.us-east-1` |
| **User** | Your Snowflake username | |
| **Password** | (Leave blank for key-pair auth) | |
| **Host** | `<account>.snowflakecomputing.com` | e.g., `xy12345.snowflakecomputing.com` |
| **Port** | `443` | Standard HTTPS port |
| **Region** | `east-us-2` | Your Snowflake region |
| **Authenticator** | `SNOWFLAKE_JWT` | **Required for key-pair authentication** |
| **Workload identity provider** | (Leave blank) | Not needed for key-pair auth |
| **Private key file** | `C:\Users\<username>\Documents\dev_sandbox\snowflake_demo_repo\keys\rsa_key.p8` | Full path to your private key |
| **Token file path** | (Leave blank or use default) | Optional |

### 4. Set Private Key Passphrase (if encrypted)

If your private key is encrypted, set the passphrase environment variable:

**For current session:**
```cmd
set PRIVATE_KEY_PASSPHRASE=your_passphrase_here
```

**For permanent setup (optional):**
- Add `PRIVATE_KEY_PASSPHRASE` to your system environment variables

### 5. Verify Connection

Test the connection:
```cmd
snow connection test
```

### 6. Login to Image Registry

Authenticate Docker with Snowflake's image registry:
```cmd
snow spcs image-registry login
```

Expected output: `Login Succeeded!!`

## Troubleshooting

### Error: "Private Key authentication requires authenticator set to SNOWFLAKE_JWT"

**Fix:** Edit `C:\Users\<username>\.snowflake\connections.toml` and set:
```toml
authenticator = "SNOWFLAKE_JWT"
```

### Error: "Encrypted private key, you must provide the passphrase"

**Fix:** Set the environment variable:
```cmd
set PRIVATE_KEY_PASSPHRASE=your_passphrase_here
```

### Connection File Location

Connections are stored at:
```
C:\Users\<username>\.snowflake\connections.toml
```

## Quick Reference Commands

```cmd
REM Test connection
snow connection test

REM List connections
snow connection list

REM Login to image registry
snow spcs image-registry login

REM View current connection
snow connection show
```

## Next Steps

After successful setup:
1. Build and push Docker images using `build_and_push.bat`
2. Create Container Services using your image repository
3. Reference: `src/ai/echo_demo/build_and_push.bat`

