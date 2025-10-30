$server = "188.245.38.217"
$user = "root"
$password = "pAdLqeRvkpJu"
$sshKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"

# Create SSH command to add key
$command = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$sshKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'SSH key added successfully'"

# Use plink if available, otherwise try PowerShell SSH
try {
    # Try using OpenSSH with password via PowerShell
    $secPassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Alternative: Create expect-like script
    $expectScript = @"
spawn ssh -o StrictHostKeyChecking=no $user@$server $command
expect "password:"
send "$password\r"
expect eof
"@

    Write-Host "Manual SSH key setup required."
    Write-Host "Please run this command manually:"
    Write-Host "ssh root@188.245.38.217"
    Write-Host "Password: pAdLqeRvkpJu"
    Write-Host "Then run: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    Write-Host "Then run: echo '$sshKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
}
catch {
    Write-Host "Error: $_"
}
