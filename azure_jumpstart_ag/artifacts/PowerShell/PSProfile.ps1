function Write-Header {
    param (
        [string]
        $title
    )

    Write-Host
    Write-Host ("#" * ($title.Length + 8))
    Write-Host "# - $title"
    Write-Host ("#" * ($title.Length + 8))
    Write-Host
}

function Redo-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 5,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$Delay = 3000
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                # If you want messages from the ScriptBlock
                # Invoke-Command -Command $ScriptBlock
                # Otherwise use this command which won't display underlying script messages
                $ScriptBlock.Invoke()
                return
            } catch {
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Start-Sleep -Milliseconds $Delay
            }
        } while ($cnt -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw 'Execution failed.'
    }
}

Function Invoke-CommandLineTool {
    #Region Parameters
    Param (
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('C')]
        [string]$CommandLine
        ,
        [Parameter(Mandatory = $False,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$WorkingDirectory
        ,
        [Parameter(Mandatory = $False,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string]$TempFilePath
        ,
        [switch]$ReturnResultObject
    )
    #EndRegion Parameters
    Begin {
    }
    Process {
        Foreach ($cmd in $CommandLine) {
            
            Write-Verbose ("CommandLine= '{0}'" -f $cmd)
            
            # File Paths
            $fn = [System.IO.Path]::GetRandomFileName() + ".bat"
            If ($TempFilePath -and (Test-Path $TempFilePath -ErrorAction SilentlyContinue)) {
                $td = $TempFilePath
            }
            Else {
                $td = [System.IO.Path]::GetTempPath()
            }
            Write-Verbose ("td= {0}" -f $td)
            
            $bat = [System.IO.Path]::Combine($td, $fn)
            New-Item -Path $bat -ItemType file | Out-Null
            Add-Content $bat $cmd
            
            $stdOutPath = Join-Path $td "stdout.log"
            $stdErrPath = Join-Path $td "stderr.log"
            
            $proc = Start-Process -Wait -PassThru -RedirectStandardOutput $stdOutPath -RedirectStandardError $stdErrPath -FilePath cmd.exe -ArgumentList @('/c', $bat) -NoNewWindow -WorkingDirectory:$WorkingDirectory
            
            @($stdOutPath, $stdErrPath) | Remove-BlankLines | Out-Null
            
            $result = "" | Select Result, ExitCode, StdOut, StdErr, StartTime, ExitTime, ElapsedTime
            $result.ExitCode = $proc.ExitCode
            $result.StdOut = Get-Content $stdOutPath | select -Skip 1 # skip prevents command line from being returned in stdOut
            $result.StdErr = Get-Content $stdErrPath
            $result.StartTime = $proc.StartTime
            $result.ExitTime = $proc.ExitTime
            $result.ElapsedTime = ($proc.ExitTime).Subtract($proc.StartTime)
            $result.Result = $result.StdOut
            
            If (-not $TempFilePath) {
                Remove-Item -Path $bat        -Force | Out-Null
                Remove-Item -Path $stdOutPath -Force | Out-Null
                Remove-Item -Path $stdErrPath -Force | Out-Null
            }
            
            If ($ReturnResultObject) {
                Return $result
            }
            Else {
                If ($result.StdErr) {
                    Write-Error ("{0}`n{1}" -f $result.StdErr, $result.StdOut)
                }
                Else {
                    Return $result.Result
                }
            }
        }
    }
    End {
    }
}

  