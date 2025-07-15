#!/bin/bash
set -e

echo "Running tests..."
./gradlew test  # or npm test, or mvn test

echo "Tests passed."
