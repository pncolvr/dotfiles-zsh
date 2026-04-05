#Requires -RunAsAdministrator
# the line above was not tested, saving here as memory helper

function updateDotnetEndeavouros {
  $dotnetRootPath="/usr/share/dotnet/shared/Microsoft.NETCore.App/"
  # $dotnetRootPath="./tests"
  $depsFilePath="Microsoft.NETCore.App.deps.json"
  $ridName="endeavouros-x64"
  $archs=@('arch-x64','arch','linux-x64','linux','unix-x64','unix','any','base')
  
  Get-ChildItem -Path "$dotnetRootPath" | Foreach-Object {
      $curDepsFilePath="$($_.FullName)/$depsFilePath"
      if(Test-Path -Path $curDepsFilePath -PathType Leaf) {
        Write-Host "Found $curDepsFilePath"
        $depsJson = Get-Content -Raw "$curDepsFilePath" | ConvertFrom-Json
        $member=$depsJson.runtimes | get-member -Name $ridName -MemberType NoteProperty
        if(-not $member) {
          Write-Host "`t$ridName not found. updating."
          $depsJson.runtimes | add-member -Name $ridName -Value $archs -MemberType NoteProperty
          $depsJson | ConvertTo-Json -depth 16 | Set-Content "$curDepsFilePath"
        } else {
          Write-Host "`t$ridName found. skipping."
        }
        # Write-Host "`n"
      }    
  }
}

if ($PSVersionTable.Platform -eq 'Unix') {
  if ((id -u) -eq 0) { 
    # we are groot
    updateDotnetEndeavouros
  } else {
    Write-Host "Please run as root"
    Write-Host "Sample:"
    Write-Host "`tsudo pwsh -Command $($MyInvocation.MyCommand.Path)"
  }
}