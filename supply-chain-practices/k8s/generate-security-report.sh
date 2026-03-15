#!/bin/bash
REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="supply-chain-security-report-$REPORT_DATE.html"

cat > "$REPORT_FILE" << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Supply Chain Security Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
    .header { background: #1E3A5F; color: white; padding: 20px; border-radius: 8px; }
    .section { background: white; margin: 20px 0; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .critical { color: #cc0000; font-weight: bold; }
    .high { color: #cc6600; font-weight: bold; }
    .ok { color: #006600; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
    th { background: #2E75B6; color: white; }
    tr:nth-child(even) { background: #f9f9f9; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Supply Chain Security Report</h1>
    <p>Generated: REPORT_DATE_PLACEHOLDER</p>
  </div>
HTML_EOF

# SBOM section
echo "  <div class='section'><h2>SBOM Summary</h2>" >> "$REPORT_FILE"
echo "  <table><tr><th>Image</th><th>Packages</th><th>SBOM Status</th></tr>" >> "$REPORT_FILE"

for image in "node:16-alpine" "python:3.9-slim"; do
  if [ -f "node-sbom.json" ] && [ "$image" = "node:16-alpine" ]; then
    COUNT=$(cat node-sbom.json | jq '.artifacts | length' 2>/dev/null || echo "N/A")
    echo "  <tr><td>$image</td><td>$COUNT</td><td class='ok'>✓ Generated</td></tr>" >> "$REPORT_FILE"
  else
    echo "  <tr><td>$image</td><td>-</td><td class='high'>Not generated</td></tr>" >> "$REPORT_FILE"
  fi
done
echo "  </table></div>" >> "$REPORT_FILE"

# Signing section
echo "  <div class='section'><h2>Image Signing Status</h2>" >> "$REPORT_FILE"
echo "  <table><tr><th>Image</th><th>Status</th></tr>" >> "$REPORT_FILE"

if cosign verify --key ~/lab14-keys/cosign.pub \
   --allow-insecure-registry localhost:5000/node:16-alpine >/dev/null 2>&1; then
  echo "  <tr><td>localhost:5000/node:16-alpine</td><td class='ok'>✓ Verified</td></tr>" >> "$REPORT_FILE"
else
  echo "  <tr><td>localhost:5000/node:16-alpine</td><td class='critical'>✗ Not Signed</td></tr>" >> "$REPORT_FILE"
fi
echo "  </table></div>" >> "$REPORT_FILE"

echo "</body></html>" >> "$REPORT_FILE"
sed -i "s/REPORT_DATE_PLACEHOLDER/$REPORT_DATE/g" "$REPORT_FILE"
echo "Report saved: $REPORT_FILE"
