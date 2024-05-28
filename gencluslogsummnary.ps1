[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $ClusterLogFilePath
)

function Get-LogSectionStartLineNumbers
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]] $Lines
    )

    $sectionStartLineNumbers = [PSCustomObject] @{
        Cluster                                 = 0
        Resources                               = 0
        Groups                                  = 0
        GroupSets                               = 0
        ResourceTypes                           = 0
        AffinityRules                           = 0
        Nodes                                   = 0
        Networks                                = 0
        NetworkInterfaces                       = 0
        Volumes                                 = 0
        VolumeLogs                              = 0
        SBLDisks                                = 0
        Certificates                            = 0
        Performance                             = 0
        System                                  = 0
        FailoverClusteringOperationalLogs       = 0
        ClusterAwareUpdatingManagementAdminLogs = 0
        ClusterAwareUpdatingAdminLogs           = 0
        FailoverClusteringDiagnosticVerbose     = 0
        ClusterLogs                             = 0
    }
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        Write-Progress -Activity 'Finding the start line numbers of each log section...' -Status ('Processing line {0} of {1}' -f ($i + 1), $lines.Length) -PercentComplete ((($i + 1) / $lines.Length) * 100)

        if ($Lines[$i].StartsWith('[=== Cluster ===]')) {
            $sectionStartLineNumbers.Cluster = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Resources ===]')) {
            $sectionStartLineNumbers.Resources = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Groups ===]')) {
            $sectionStartLineNumbers.Groups = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Group Sets ===]')) {
            $sectionStartLineNumbers.GroupSets = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Resource Types ===]')) {
            $sectionStartLineNumbers.ResourceTypes = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Affinity Rules ===]')) {
            $sectionStartLineNumbers.AffinityRules = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Nodes ===]')) {
            $sectionStartLineNumbers.Nodes = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Networks ===]')) {
            $sectionStartLineNumbers.Networks = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Network Interfaces ===]')) {
            $sectionStartLineNumbers.NetworkInterfaces = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Volumes ===]')) {
            $sectionStartLineNumbers.Volumes = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Volume Logs ===]')) {
            $sectionStartLineNumbers.VolumeLogs = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== SBL Disks ===]')) {
            $sectionStartLineNumbers.SBLDisks = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Certificates ===]')) {
            $sectionStartLineNumbers.Certificates = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Performance ===]')) {
            $sectionStartLineNumbers.Performance = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== System ===]')) {
            $sectionStartLineNumbers.System = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Microsoft-Windows-FailoverClustering/Operational logs ===]')) {
            $sectionStartLineNumbers.FailoverClusteringOperationalLogs = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Microsoft-Windows-ClusterAwareUpdating-Management/Admin logs ===]')) {
            $sectionStartLineNumbers.ClusterAwareUpdatingManagementAdminLogs = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Microsoft-Windows-ClusterAwareUpdating/Admin logs ===]')) {
            $sectionStartLineNumbers.ClusterAwareUpdatingAdminLogs = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Microsoft-Windows-FailoverClustering/DiagnosticVerbose ===]')) {
            $sectionStartLineNumbers.FailoverClusteringDiagnosticVerbose = $i + 1
        }
        elseif ($Lines[$i].StartsWith('[=== Cluster Logs ===]')) {
            $sectionStartLineNumbers.ClusterLogs = $i + 1
        }
    }
    
    Write-Progress -Completed

    return $sectionStartLineNumbers
}

function Get-ClusterLogLineParts
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RawLine
    )

    $parts = [PSCustomObject] @{
        ProcessId = ''
        ThreadId  = ''
        Timestamp = ''
        Level     = ''
        Message   = ''
    }

    if ($rawLine -match '^(.{8})\.(.{8})::(\d{4}\/\d{2}\/\d{2}\-\d{2}:\d{2}:\d{2}\.\d{3})\s(.{4})\s{2}(.*)$') {
        $parts.ProcessId = $Matches[1]
        $parts.ThreadId = $Matches[2]
        $parts.Timestamp = [datetime]::ParseExact($Matches[3], 'yyyy/MM/dd-HH:mm:ss.fff', $null)
        $parts.Level = $Matches[4]
        $parts.Message = $Matches[5]
    }
    else {
        throw 'The raw log line is not in the expected format.'
    }

    return $parts
}

function Get-ClusterSecrionSummary
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]] $Lines,

        [Parameter(Mandatory = $true)]
        [long] $ClusterSectionFirstLineNum,

        [Parameter(Mandatory = $true)]
        [long] $ResourcesSectionFirstLineNum
    )

    $summary = [PSCustomObject] @{
        BuildNumber    = ''
        TimeZoneOffset = ''
        UseLocalTime   = $false
        CurrentNode    = ''
    }

    for ($i = $ClusterSectionFirstLineNum; $i -lt $ResourcesSectionFirstLineNum; $i++) {
        if ($Lines[$i].StartsWith('Build Number')) {
            if ($Lines[$i] -match '^Build Number (\d+)$') {
                $summary.BuildNumber = $Matches[1]
            }
        }
        elseif ($Lines[$i].StartsWith('UTC = localtime + time zone offset;')) {
            if ($Lines[$i] -match '^UTC = localtime \+ time zone offset;the time zone offset of this machine is (.+)$') {
                $summary.TimeZoneOffset = $Matches[1]
            }
        }
        elseif ($Lines[$i].StartsWith('The logs were generated using local time')) {
            $summary.UseLocalTime = $true
        }
        elseif ($Lines[$i].StartsWith('Current node:')) {
            if ($Lines[$i] -match '^Current node: name \((.+)\) id \(\d+\)$') {
                $summary.CurrentNode = $Matches[1]
            }
        }
    }

    return $summary
}

function Get-ClusterLogsSecrionSummary
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]] $Lines,

        [Parameter(Mandatory = $true)]
        [long] $FirstLineNum
    )

    $firstLog = Get-ClusterLogLineParts -RawLine $Lines[$FirstLineNum]
    $lastLog = Get-ClusterLogLineParts -RawLine $Lines[$lines.Length - 1]

    $summary = [PSCustomObject] @{
        FristLog = $firstLog.Timestamp.ToString('yyyy/MM/dd-HH:mm:ss.fff')
        LastLog  = $lastLog.Timestamp.ToString('yyyy/MM/dd-HH:mm:ss.fff')
    }

    return $summary
}

Write-Verbose -Message ('Reading the cluster log file: "{0}"' -f $ClusterLogFilePath)
$lines = Get-Content -LiteralPath $ClusterLogFilePath -Encoding unicode

Write-Verbose -Message 'Finding the start line numbers of each log section.'
$logSectionStartLineNumbers = Get-LogSectionStartLineNumbers -Lines $lines

Write-Host -Object '=== First line number of each section ===' -ForegroundColor Cyan
$logSectionStartLineNumbers

Write-Host -Object '=== Cluster Secrion Summary ===' -ForegroundColor Cyan
Get-ClusterSecrionSummary -Lines $lines -ClusterSectionFirstLineNum $logSectionStartLineNumbers.Cluster -ResourcesSectionFirstLineNum $logSectionStartLineNumbers.Resources

Write-Host -Object '=== Cluster Logs Secrion Summary ===' -ForegroundColor Cyan
Get-ClusterLogsSecrionSummary -Lines $lines -FirstLineNum $logSectionStartLineNumbers.ClusterLogs
