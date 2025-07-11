# Prisma Cloud Integration Setup Guide

This guide explains how to integrate Prisma Cloud (formerly Twistlock) with the Golden Image Build System for enhanced security scanning and compliance checking.

## Overview

Prisma Cloud provides enterprise-grade security scanning that complements the existing Trivy integration. It offers:

- **Advanced Vulnerability Scanning**: Deep scanning of container images
- **Compliance Checking**: CIS, HIPAA, PCI, SOX, and NIST compliance
- **Secret Detection**: Find hardcoded secrets and credentials
- **Malware Detection**: Identify malicious software in images
- **Detailed Reporting**: Comprehensive HTML and JSON reports

## Prerequisites

### 1. Prisma Cloud Account
- Active Prisma Cloud subscription
- Access to Prisma Cloud Console
- API credentials (Access Key and Secret Key)

### 2. Prisma Cloud CLI Installation

#### Download CLI
1. Log into your Prisma Cloud Console
2. Navigate to **Manage** → **System** → **Utilities**
3. Download the appropriate CLI for your platform:
   - **Linux**: `twistcli-linux`
   - **macOS**: `twistcli-macos`
   - **Windows**: `twistcli-windows.exe`

#### Install CLI
```bash
# Linux/macOS
chmod +x twistcli-linux
sudo mv twistcli-linux /usr/local/bin/twistcli

# Windows
# Move twistcli-windows.exe to a directory in your PATH
```

#### Verify Installation
```bash
twistcli --version
```

## Configuration

### 1. Update Prisma Cloud Configuration

Edit `configs/prisma-config.env` with your Prisma Cloud details:

```bash
# Prisma Cloud Console Configuration
PRISMA_CONSOLE_URL=https://your-prisma-console.com
PRISMA_ACCESS_KEY=your-access-key
PRISMA_SECRET_KEY=your-secret-key

# Scanning Configuration
SCAN_SEVERITY=high,critical
COMPLIANCE_PROFILE=CIS-1.0
OUTPUT_FORMAT=json
REPORTS_DIR=reports/prisma
```

### 2. Test Authentication

```bash
# Test Prisma Cloud connection
twistcli images scan \
  --address "$PRISMA_CONSOLE_URL" \
  --user "$PRISMA_ACCESS_KEY" \
  --password "$PRISMA_SECRET_KEY" \
  --help
```

## Usage

### 1. Run Prisma Cloud Scan Only

```bash
# Scan all images with Prisma Cloud
make scan-prisma

# Or run the script directly
./scripts/prisma-scan.sh
```

### 2. Run Comprehensive Scan (Trivy + Prisma Cloud)

```bash
# Run both Trivy and Prisma Cloud scans
make scan-comprehensive

# Or run the script directly
./scripts/comprehensive-scan.sh
```

### 3. Scan Specific Images

```bash
# Scan a single image
./scripts/comprehensive-scan.sh --single-image debian-hardened:latest

# Scan with Prisma Cloud only
./scripts/comprehensive-scan.sh --prisma-only --single-image nginx-platform:latest
```

## Scanning Options

### Severity Levels
```bash
# Configure in configs/prisma-config.env
SCAN_SEVERITY=low,medium,high,critical
```

### Compliance Profiles
```bash
# Available compliance profiles
COMPLIANCE_PROFILE=CIS-1.0      # CIS Container Security Benchmark
COMPLIANCE_PROFILE=HIPAA         # Health Insurance Portability and Accountability Act
COMPLIANCE_PROFILE=PCI           # Payment Card Industry Data Security Standard
COMPLIANCE_PROFILE=SOX           # Sarbanes-Oxley Act
COMPLIANCE_PROFILE=NIST          # National Institute of Standards and Technology
```

### Output Formats
```bash
# Available output formats
OUTPUT_FORMAT=json              # JSON format (recommended)
OUTPUT_FORMAT=table             # Table format (human readable)
OUTPUT_FORMAT=csv               # CSV format (for spreadsheets)
OUTPUT_FORMAT=sarif             # SARIF format (for GitHub Security)
```

## Advanced Configuration

### 1. Custom Compliance Rules

Create custom compliance rules in Prisma Cloud Console:

1. Navigate to **Defend** → **Compliance**
2. Create custom compliance rules
3. Reference them in your scans

### 2. Integration with CI/CD

#### GitHub Actions
Add these secrets to your GitHub repository:

```bash
PRISMA_CONSOLE_URL=https://your-prisma-console.com
PRISMA_ACCESS_KEY=your-access-key
PRISMA_SECRET_KEY=your-secret-key
```

#### Azure DevOps
Add these variables to your pipeline:

```yaml
variables:
  PRISMA_CONSOLE_URL: 'https://your-prisma-console.com'
  PRISMA_ACCESS_KEY: '$(prisma-access-key)'
  PRISMA_SECRET_KEY: '$(prisma-secret-key)'
```

### 3. Alerting and Notifications

Configure notifications in `configs/prisma-config.env`:

```bash
# Slack Integration
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Email Notifications
EMAIL_RECIPIENTS=security@yourcompany.com

# JIRA Integration
JIRA_PROJECT_KEY=SEC
JIRA_URL=https://yourcompany.atlassian.net
```

## Reports and Output

### 1. Report Locations
- **Prisma Cloud reports**: `reports/prisma/`
- **Comprehensive reports**: `reports/comprehensive-security-report.html`
- **Individual scan reports**: `reports/prisma/{image-name}-prisma-scan.json`

### 2. Report Types

#### Vulnerability Reports
```json
{
  "vulnerabilities": [
    {
      "id": "CVE-2023-1234",
      "severity": "high",
      "package": "openssl",
      "version": "1.1.1k",
      "description": "Vulnerability description"
    }
  ]
}
```

#### Compliance Reports
```json
{
  "compliance": [
    {
      "id": "CIS-1.0-1.1",
      "severity": "high",
      "title": "Ensure the container host is properly configured",
      "description": "Compliance requirement description"
    }
  ]
}
```

### 3. HTML Reports
Generate comprehensive HTML reports with:
- Executive summary
- Vulnerability details
- Compliance violations
- Security recommendations
- Next steps

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```bash
# Check credentials
echo "Testing Prisma Cloud authentication..."
twistcli images scan \
  --address "$PRISMA_CONSOLE_URL" \
  --user "$PRISMA_ACCESS_KEY" \
  --password "$PRISMA_SECRET_KEY" \
  --help
```

#### 2. Network Connectivity
```bash
# Test network connectivity
curl -I "$PRISMA_CONSOLE_URL"
```

#### 3. CLI Not Found
```bash
# Check if twistcli is in PATH
which twistcli

# Add to PATH if needed
export PATH=$PATH:/path/to/twistcli
```

#### 4. Permission Issues
```bash
# Make script executable
chmod +x scripts/prisma-scan.sh
chmod +x scripts/comprehensive-scan.sh
```

### Debug Mode

Enable debug output:

```bash
# Set debug environment variable
export PRISMA_DEBUG=true

# Run scan with verbose output
./scripts/prisma-scan.sh
```

## Best Practices

### 1. Regular Scanning
- Run scans after each image build
- Schedule weekly comprehensive scans
- Monitor for new vulnerabilities

### 2. Threshold Management
Configure failure thresholds in `configs/prisma-config.env`:

```bash
MAX_CRITICAL_VULNERABILITIES=0
MAX_HIGH_VULNERABILITIES=5
MAX_COMPLIANCE_VIOLATIONS=10
```

### 3. Report Management
- Archive old reports
- Set up automated report distribution
- Integrate with security dashboards

### 4. Performance Optimization
- Use appropriate scan timeouts
- Configure scan threads
- Optimize network connectivity

## Integration Examples

### 1. Pre-deployment Scanning
```bash
# Scan before deployment
./scripts/comprehensive-scan.sh --single-image myapp:latest
if [ $? -eq 0 ]; then
    echo "Security scan passed, proceeding with deployment"
    # Deploy application
else
    echo "Security scan failed, blocking deployment"
    exit 1
fi
```

### 2. Continuous Monitoring
```bash
# Set up cron job for regular scanning
0 2 * * * /path/to/golden-image/scripts/comprehensive-scan.sh
```

### 3. Automated Remediation
```bash
# Check for critical vulnerabilities
./scripts/prisma-scan.sh
if grep -q "CRITICAL" reports/prisma/*.json; then
    echo "Critical vulnerabilities found, triggering rebuild"
    make build-all
fi
```

## Support

For Prisma Cloud specific issues:
1. Check Prisma Cloud documentation
2. Contact Prisma Cloud support
3. Review Prisma Cloud community forums

For integration issues:
1. Check the troubleshooting section
2. Review logs and error messages
3. Open an issue in the repository

## License

This integration is part of the Golden Image Build System and follows the same MIT License. 