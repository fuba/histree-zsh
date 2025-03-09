# histree-zsh

A Zsh plugin that integrates with [histree-core](https://github.com/fuba/histree-core) to provide enhanced command history logging with directory awareness.

This project was developed with the assistance of ChatGPT and GitHub Copilot.

## Features

- Automatic command logging with directory context
- Exit code tracking for each command execution
- Multiple output formats for viewing history:
  - Simple format: Just the command
  - Verbose format: With timestamp and directory context
  - JSON format: For programmatic access
- Seamless integration with your Zsh workflow

## Prerequisites

- Zsh shell
- Go 1.18 or later
  ```sh
  # Check your Go version
  go version
  ```
- Properly configured GOBIN in your PATH
  ```sh
  # Add this to your ~/.zshrc or ~/.bashrc if not already set
  export GOBIN=$HOME/go/bin
  export PATH=$GOBIN:$PATH
  ```

## Installation

1. Clone this repository:
    ```sh
    git clone https://github.com/fuba/histree-zsh.git
    cd histree-zsh
    ```

2. Make sure your Go environment is properly set up:
    ```sh
    # Verify your Go environment
    echo $GOBIN
    echo $PATH
    ```

3. Run the installation script:
    ```sh
    chmod +x ./install.sh  # Make sure the script is executable
    ./install.sh
    ```

The script will:
- Create `~/.histree-zsh` directory structure
- Install histree-core using `go install`
- Copy the histree-core binary to the correct location
- Add necessary configurations to your `.zshrc`

After installation:
```
~/.histree-zsh/
├── bin/          # Contains the histree-core binary
└── histree.zsh   # The Zsh plugin script
```

## Configuration

The plugin behavior can be customized in your `.zshrc`:

```zsh
# Database location (optional)
export HISTREE_DB="$HOME/.histree.db"  # Default location

# History entries limit (optional)
export HISTREE_LIMIT=500  # Default: 100
```

## Usage

Once installed, restart your terminal or run:
```sh
source ~/.zshrc
```

The plugin automatically logs your commands. View history using:

```sh
# Simple format (default)
$ histree
git status
npm install
vim README.md

# Verbose format with timestamps and directories
$ histree -v
2024-02-15T15:04:30Z [/home/user/project] [0] git status
2024-02-15T15:05:15Z [/home/user/project] [1] npm install
2024-02-15T15:06:00Z [/home/user/project] [0] vim README.md

# JSON format
$ histree -json
{"command":"git status","directory":"/home/user/project","timestamp":"2024-02-15T15:04:30Z","exit_code":0,"hostname":"host","process_id":1234}
{"command":"npm install","directory":"/home/user/project","timestamp":"2024-02-15T15:05:15Z","exit_code":1,"hostname":"host","process_id":1234}
{"command":"vim README.md","directory":"/home/user/project","timestamp":"2024-02-15T15:06:00Z","exit_code":0,"hostname":"host","process_id":1234}
```

### Command Options
- `-v`, `--verbose`: Show detailed output including timestamp, directory, and exit code
- `-json`, `--json`: Output in JSON format with full command context

### Troubleshooting

```sh
# Check binary installation
which histree-core        # Should show: ~/.histree-zsh/bin/histree-core

# Check database permissions
ls -l ~/.histree.db

# Verify PATH setting
echo $PATH | grep histree

# Fix binary permissions if needed
chmod +x ~/.histree-zsh/bin/histree-core

# Reset database if corrupted
rm ~/.histree.db    # New one will be created automatically
```

## License

MIT License
