<#
.SYNOPSIS
Run staging deployment for Bicep registry

.DESCRIPTION
Used for local development to deploy bicep modules to the staging ACR bicep registry and deploy test resources

.PARAMETER customerCode
Mandatory. The customerCode string which will replace <CUSTOMERCODE> in the config file

.PARAMETER environment
Mandatory. The environment string which will replace <<ENVIRONMENT>> in the config file

The resource group must exist before deploying in the following format: <CUSTOMERCODE>-<ENVIRONMENT>-rg
#>

#Parameters
[CmdletBinding(PositionalBinding = $False)]
param (
    [Parameter(Mandatory=$true)]    
    [string]$customerCode,

    [Parameter(Mandatory=$true)]
    [string]$environment,

    [Parameter(Mandatory=$false)]    
    [string]$mainFile = "main.bicep",

    [Parameter(Mandatory=$false)]    
    [string]$initFile = "init.bicep",

    [Parameter(Mandatory=$false)]    
    [string]$configFile = "..\configs\config.jsonc" 
)

#Stop script if try- catch failes
$ErrorActionPreference = "Stop"

##Variables
#Bicep config
$bicepConfig = Get-Content -Raw -Path bicepconfig.json | ConvertFrom-Json
$loginServer = $bicepConfig.moduleAliases.br.registry.registry
##Bicep files
$mainBicepFile = Join-Path -Path $PSScriptRoot -ChildPath "\$mainFile"
$initBicepFile = Join-Path -Path $PSScriptRoot -ChildPath "\$initFile"
##Config file
$jsonConfigc = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "\$configFile") -Raw
$jsonConfig = $jsonConfigc -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/' -replace '<CUSTOMERCODE>', $customerCode -replace '<ENVIRONMENT>', $environment
$jsonConfig | Out-File -FilePath ./configtemp.json -Encoding utf8
$config = Get-Content ./configtemp.json -Raw | ConvertFrom-Json -Depth 100
##TemplateFile
$templatesConfig = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "\templates.jsonc") -Raw | ConvertFrom-Json

Function Main(){
    Remove-LocalCache

    Deploy-StagingTemplates $initBicepFile $loginServer $templatesConfig
    Deploy-StagingTemplates $mainBicepFile $loginServer $templatesConfig
    Deploy-BicepResources $initBicepFile $config
    Deploy-BicepResources $mainBicepFile $config

    Remove-Item ./configtemp.json
}

Function Remove-LocalCache{
    #Remove local bicep file
    $cacheFolder = "$env:USERPROFILE\.bicep\br\"
    write-host "Checking if local bicep cache folders exists in: $cacheFolder" -ForeGroundColor Yellow 
    if (Test-Path -path $cacheFolder){
        write-host "Removing local bicep cache folders in $cacheFolder" -ForeGroundColor Yellow
        Remove-Item "$cacheFolder*" -Recurse -Force
    }
    write-host " "
}


Function Deploy-StagingTemplates($bicepFile,$loginServer,$templatesConfig){
    write-host "############################################" -ForegroundColor Cyan
    write-host "Publising modules in $bicepFile to $loginServer" -ForegroundColor Cyan
    write-host "############################################" -ForegroundColor Cyan

    $getModules = Get-Content -Path $bicepFile | Select-String -Pattern "^module" | Where-Object { $_ -notlike '*example*' }
    Write-Host "Modules found are:"
    $getModules | ForEach-Object { Write-Host "$_" -ForeGroundColor Green} 
    Write-Host " "
    if($getModules){
        foreach($module in $getModules){
            $moduleSplit = $module.Line.Split(" ")
            $moduleArtifact = $moduleSplit[2]
            $moduleArtifactSplit = $moduleArtifact.Split(":")
            $moduleName = $moduleArtifactSplit[1]
            $version = $moduleArtifactSplit[2] -replace("'","")
            $getTemplate = $templatesConfig | Where-Object {$_.name -eq $moduleName}
            if(($getTemplate -ne $null) -and (($getTemplate | Measure-Object).count -eq 1)){
                write-host $moduleName -ForeGroundColor Magenta 
                $filePath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\..\$($getTemplate.filePath)"
                write-host "    Publishing $moduleName module to $loginServer with version $version" -ForegroundColor Cyan
                az bicep publish `
                    --file $filePath `
                    --target "br:${loginServer}/bicep/modules/${moduleName}:$version" `
                    --force `
                    --verbose
                if($LASTEXITCODE){
                    exit
                }
                write-host "    Module $moduleName has been published to $loginServer"  -ForeGroundColor Green
                write-host " "
            }
            else{
                throw "Module $moduleName is missing or multiple modules exists for $moduleName in the template file templates.jsonc"
            }
        }
    }
}

Function Deploy-BicepResources{
    param(
        [string]$bicepFile,
        [object]$config,
        [string]$bicepParamfile
    )
    write-host "############################################" -ForegroundColor Cyan
    write-host "Deploying Bicep resources with $bicepFile" -ForegroundColor Cyan
    write-host "############################################" -ForegroundColor Cyan
    

    $getResources = az resource list -g $config.ResourceGroupName --query "[].name"
    $TempFile = (New-TemporaryFile).FullName
    $getResources | Out-File -FilePath $TempFile
    if (!$?) {
        throw "Unable to retrieve existing resources"
    }

    $Components = New-Object System.Collections.Generic.List[System.String]

    [System.Action[string, action]] $ExecuteDeployment = {
        param($DeploymentName, $Action)
        
        Write-Host "Deploying: ${DeploymentName}" -ForegroundColor Cyan
        try {
            $Action.invoke()
        }
        catch {
            Write-Host "Unable to deploy '${DeploymentName}':" -ForegroundColor Red
            Throw $_ 
        }
        $Components.Add($DeploymentName)
    }

    #Deploy Bicep resources with config file
    if(!$bicepParamfile){
        $ExecuteDeployment.invoke("Bicep resources", {
            az deployment group create `
                --resource-group $Config.ResourceGroupName `
                --subscription $Config.SubscriptionId `
                --template-file "$bicepFile" `
                --parameters "config=`@./configtemp.json" "existingResources=`@$($TempFile)"
            if (!$?) {
                throw "Unable to deploy resources"
            }
        })
    }
    else{
    #Deploy Bicep resources with bicepparam file
        $ExecuteDeployment.invoke("Bicep resources", {
            az deployment group create `
                --resource-group $Config.ResourceGroupName `
                --subscription $Config.SubscriptionId `
                --template-file "$bicepFile" `
                --parameters "$bicepParamfile"
            if (!$?) {
                throw "Unable to deploy resources"
            }
        })
    }
    
    Write-Host 'Deployment finished. Installed components:' -ForegroundColor Green
    $Components
}

Main