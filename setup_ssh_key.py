#!/usr/bin/env python3
"""
Script to setup SSH key on remote server
"""
import os
import sys

try:
    import paramiko
except ImportError:
    print("Error: paramiko not installed")
    print("Installing paramiko...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko"])
    import paramiko

def setup_ssh_key():
    # Configuration
    hostname = "188.245.38.217"
    username = "root"
    password = "pAdLqeRvkpJu"

    # Read SSH public key
    ssh_key_path = os.path.expanduser("~/.ssh/id_rsa.pub")
    with open(ssh_key_path, 'r') as f:
        public_key = f.read().strip()

    print(f"Connecting to {hostname}...")

    # Create SSH client
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        # Connect with password
        client.connect(hostname, username=username, password=password, timeout=10)
        print("Connected successfully!")

        # Commands to setup SSH key
        commands = [
            "mkdir -p ~/.ssh",
            "chmod 700 ~/.ssh",
            f"echo '{public_key}' >> ~/.ssh/authorized_keys",
            "chmod 600 ~/.ssh/authorized_keys",
            "sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys",  # Remove duplicates
            "echo 'SSH key setup complete'"
        ]

        for cmd in commands:
            print(f"Executing: {cmd[:50]}...")
            stdin, stdout, stderr = client.exec_command(cmd)
            exit_status = stdout.channel.recv_exit_status()

            if exit_status != 0:
                error = stderr.read().decode()
                print(f"Warning: {error}")

        # Verify SSH key
        stdin, stdout, stderr = client.exec_command("cat ~/.ssh/authorized_keys | grep -c 'ssh-rsa'")
        key_count = stdout.read().decode().strip()
        print(f"\nSSH key installed successfully!")
        print(f"Total keys in authorized_keys: {key_count}")

    except Exception as e:
        print(f"Error: {e}")
        return False
    finally:
        client.close()

    return True

if __name__ == "__main__":
    if setup_ssh_key():
        print("\n✓ SSH key setup completed successfully!")
        print("You can now connect without password: ssh root@188.245.38.217")
    else:
        print("\n✗ SSH key setup failed")
        sys.exit(1)
