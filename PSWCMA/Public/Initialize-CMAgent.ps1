﻿Function Initialize-CMAgent {
    <#
      .Synopsis
      Configures the Agent on the Client with all needed Dependencies

      .Description
      Configures the Agent on the Client with all needed Dependencies

      .Parameter Path
      Filepath for the working directory for this agent

      .Parameter Git
      Give the link to your Git Repository. Repo must be public to allow anonymous access

      .Parameter ActiveDirectory
      FQDN for your Active Directory

      .Parameter Filter
      The AD Filter for the group prefix which should be searched

      .Parameter Baseline
      The baseline configuration which always shoudld be applied. Only exists in git

      .Example
      Initialize-CMAgent -Path "C:\ProgramData\Unibasel\CCM" -Git "https://github.com/your-repo.git" -ActiveDirectory "Your.ActiveDirectory.com" -Filter "prefix-ccm*" -Baseline "prefix-ccm-baseline"

  #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias('p')]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [Alias('g')]
        [string]$Git,
        [Parameter(Mandatory = $true)]
        [Alias('ad')]
        [string]$ActiveDirectory,
        [Parameter(Mandatory = $true)]
        [Alias('f')]
        [string]$Filter,
        [Parameter(Mandatory = $true)]
        [Alias('b')]
        [string]$Baseline

    )
    begin {
        $PreReq = Test-Prerequisites
        $RegPath = 'HKLM:\SOFTWARE\PSWCMA'
    }
    process {
        #Write Configuration Cache
        New-Item -Path $RegPath -Force
        New-ItemProperty -Path $RegPath -Name 'FilePath' -Value $Path -PropertyType String -Force
        New-ItemProperty -Path $RegPath -Name 'Git' -Value $Git -PropertyType String -Force
        New-ItemProperty -Path $RegPath -Name 'ActiveDirectory' -Value $ActiveDirectory -PropertyType String -Force
        New-ItemProperty -Path $RegPath -Name 'AdFilter' -Value $Filter -PropertyType String -Force
        New-ItemProperty -Path $RegPath -Name 'BaseLineConfig' -Value $Baseline -PropertyType String -Force

        #Install Pre-Reqs
        if (!$PreReq.Win10) {
            Write-Error 'This is not a Windows 10 Device. Going to End'
            break
        }
        if (!$PreReq.Git) {
            Install-Git
        }
        if (!$PreReq.WinRM) {
            Set-WSManQuickConfig -Force
        }
        if (!$PreReq.CFW) {
            Install-Module -Name 'cFirewall' -Force -Confirm:$false
        }
        if (!$PreReq.XPSDSC) {
            Install-Module -Name 'xPSDesiredStateConfiguration' -Force -Confirm:$false
        }

        if (!(Test-Prerequisites).All) {
            Write-Error 'There was an error installing the Prequisites'
            break
        }

        try {
            #Configure Scheduler
            $Random = Get-Random -Maximum 15
            $SchedulerAction = New-ScheduledTaskAction -Execute 'powershell' -Argument '-NoProfile -WindowStyle Hidden -command "& {Import-Module PSWCMA; Install-Configurations}"'
            $SchedulerTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days (365 * 20)) -RandomDelay (New-TimeSpan -Minutes $Random)
            $SchedulerSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)
            Register-ScheduledTask -User System -TaskName 'Configuration Management Agent' -Action $SchedulerAction -Trigger $SchedulerTrigger -Settings $SchedulerSettings -Force
        } catch {
          Write-Error -Message $_.Exception.Message
          Write-Debug "There was an error creating the scheduled task. Please try again"
        }

    }
    end {

    }

}