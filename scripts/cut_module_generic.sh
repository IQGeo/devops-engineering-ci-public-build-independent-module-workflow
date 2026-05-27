#!/bin/bash
set -e

# Generic module cut script for independent module builds
# This script creates a deliverable tarball from module source code
#
# Usage: cut_module_generic.sh MODULE VERSION SOURCE_DIR OUTPUT_DIR
#
# Arguments:
#   MODULE      - Module name (e.g., cyclomedia_integration)
#   VERSION     - Module version (e.g., 1.0.0)
#   SOURCE_DIR  - Directory containing the module (e.g., /path/to/modules)
#   OUTPUT_DIR  - Directory where artifacts will be created
#
# Outputs:
#   - IQGeo_${MODULE}_${VERSION}.tar.gz  (module tarball)
#   - version_info.json                   (version metadata)

MODULE=$1
VERSION=$2
SOURCE_DIR=$3
OUTPUT_DIR=$4

# Validate arguments
if [[ -z "$MODULE" || -z "$VERSION" || -z "$SOURCE_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "❌ ERROR: Missing required arguments"
  echo "Usage: $0 MODULE VERSION SOURCE_DIR OUTPUT_DIR"
  echo ""
  echo "Example:"
  echo "  $0 cyclomedia_integration 1.0.0 /path/to/modules /path/to/output"
  exit 1
fi

# Validate source directory exists
if [[ ! -d "$SOURCE_DIR/$MODULE" ]]; then
  echo "❌ ERROR: Module directory not found: $SOURCE_DIR/$MODULE"
  exit 1
fi

echo "========================================"
echo "Generic Module Cut Script"
echo "========================================"
echo "Module:     $MODULE"
echo "Version:    $VERSION"
echo "Source:     $SOURCE_DIR/$MODULE"
echo "Output:     $OUTPUT_DIR"
echo "========================================"

# Change to module directory
cd "$SOURCE_DIR/$MODULE"

# Display module contents
echo ""
echo "Module contents:"
ls -lah

# Generate version_info.json
echo ""
echo "Generating version_info.json..."
echo "{\"${MODULE}\": \"${VERSION}\"}" > "$SOURCE_DIR/$MODULE/version_info.json"

# Verify version file was created
if [[ ! -f "$SOURCE_DIR/$MODULE/version_info.json" ]]; then
  echo "❌ ERROR: Failed to create version_info.json"
  exit 1
fi

# Create tarball with standard exclusions
echo ""
echo "Creating tarball..."
tar czf "$OUTPUT_DIR/IQGeo_${MODULE}_${VERSION}.tar.gz" \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='.gitignore' \
  --exclude='.gitattributes' \
  --exclude='*.pyc' \
  --exclude='*.pyo' \
  --exclude='__pycache__' \
  --exclude='node_modules' \
  --exclude='.vscode' \
  --exclude='.idea' \
  --exclude='*.swp' \
  --exclude='*.swo' \
  --exclude='*~' \
  --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='.eggs' \
  --exclude='*.egg-info' \
  --exclude='.pytest_cache' \
  --exclude='.coverage' \
  --exclude='htmlcov' \
  --exclude='dist' \
  --exclude='build' \
  .

# Verify tarball was created
if [[ ! -f "$OUTPUT_DIR/IQGeo_${MODULE}_${VERSION}.tar.gz" ]]; then
  echo "❌ ERROR: Failed to create tarball"
  exit 1
fi



# Display results
echo ""
echo "========================================"
echo "✅ Cut completed successfully"
echo "========================================"
echo "Created artifacts:"
echo "  - IQGeo_${MODULE}_${VERSION}.tar.gz ($(du -h "$OUTPUT_DIR/IQGeo_${MODULE}_${VERSION}.tar.gz" | cut -f1))"
echo "  - version_info.json"
echo ""
echo "version_info.json content:"
cat "$OUTPUT_DIR/version_info.json"
echo ""
echo "Output directory contents:"
ls -lh "$OUTPUT_DIR"
echo "========================================"
