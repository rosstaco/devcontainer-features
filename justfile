# Copy feature to .devcontainer for local testing
build-feature feature:
    #!/usr/bin/env bash
    set -e
    echo "Copying {{feature}} feature to .devcontainer..."
    rm -rf .devcontainer/{{feature}}
    mkdir -p .devcontainer/{{feature}}
    cp src/{{feature}}/devcontainer-feature.json .devcontainer/{{feature}}/
    cp src/{{feature}}/install.sh .devcontainer/{{feature}}/
    echo "✓ Feature copied to .devcontainer/{{feature}}"

# Build Oh My Posh feature
build-ohmyposh:
    just build-feature ohmyposh

# Build all features
build-all:
    just build-ohmyposh

# Clean copied features
clean:
    rm -rf .devcontainer/ohmyposh
    rm -f .devcontainer/*.tgz
    echo "✓ Cleaned local features"
