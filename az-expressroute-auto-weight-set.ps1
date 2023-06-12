function Connect-ToAzureAccount {
  # INSERT CREDENTIAL HERE
  $Cred = [PSCustomObject]@{
    TenantId = "<tenand_id>"
    SubscriptionId = "<subscription_id>"
    AplicationId ="<application_id>"
    ApplicationSecret = ConvertTo-SecureString "<application_secret>" -AsPlainText -Force
  }
  try {
    $psCred = New-Object System.Management.Automation.PSCredential($Cred.AplicationId , $Cred.ApplicationSecret)
    Connect-AzAccount -ServicePrincipal -Credential $psCred -Tenant $Cred.TenantId -Subscription $Cred.SubscriptionId
  }
  catch {
    throw $_
  }
}

function Set-VpnConnectionWeight {
  param (
    [Parameter(Mandatory=$true)]
    [string]$ConnectionName,
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [Int]$RoutingWeight
  )
  try {
    $ConnectionInfo = Get-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $ResourceGroupName
    $ConnectionInfo.RoutingWeight = $RoutingWeight
    Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $ConnectionInfo -Force
  }
  catch {
    # IF RELATED TO CAN'T AUTHORIZE TRY CONNECT TO AZURE ACCOUNT AND RETRY
    if ($_.Exception.Message -like "*AuthorizationFailed*") {
      i = 0
      while (i -le 5) {
        Connect-ToAzureAccount
        $ConnectionInfo = Get-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $ResourceGroupName
        $ConnectionInfo.RoutingWeight = $RoutingWeight
        Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $ConnectionInfo -Force
        Write-Error -Exception "Try $($i): $($_.Exception.Message) Try again in 10 seconds"
        sleep -seconds 10
        if (i -eq 5) {
          throw $_
        }
      }
    } else {
      throw $_
    }
  }
}

# INSERT INFO HERE
$PrimaryRouteIpAddress = "<primary_route_ip_address>"
$PrimaryERConnectionName = "<primary_er_connection_name>"
$SecondaryERConnectionName = "<secondary_er_connection_name>"
$ResourceGroup = "<resource_group>"

# Monitor the primary route IP address, if it is not reachable, set the Routing weight of secondary connection to 30 and primary connection to 20
while ($true) {
  sleep -seconds 15
  # Ping the on-prem IP address
  $ping = Test-NetConnection $PrimaryRouteIpAddress
  Write-Host "Primary Route $($ping.RemoteAddress): $($ping.PingSucceeded)"
  if ($ping.PingSucceeded -eq $false) {
    # If ping is not successful
    # Get the current time
    $currentTime = Get-Date
    # Connect to Azure Account
    Connect-ToAzureAccount
    # Set the Routing weight of secondary connection to 30 and primary connection to 20
    Set-VpnConnectionWeight -ConnectionName $PrimaryERConnectionName -ResourceGroupName $ResourceGroup -RoutingWeight 20
    Set-VpnConnectionWeight -ConnectionName $SecondaryERConnectionName -ResourceGroupName $ResourceGroup -RoutingWeight 30
    Write-Host "$($currentTime): Ping to $PrimaryRouteIpAddress failed. Set the Routing weight of secondary connection to 30 and primary connection to 20"

    # Monitor the primary route IP address, if it is reachable, set the Routing weight of secondary connection to 20 and primary connection to 30
    while ($true) {
      # Ping the on-prem IP address
      $ping = Test-NetConnection $PrimaryRouteIpAddress
      Write-Host "Primary Route $($ping.RemoteAddress): $($ping.PingSucceeded)"
      if ($ping.PingSucceeded -eq $true) {
        # If ping is successful
        # Get the current time
        $currentTime = Get-Date
        # Connect to Azure Account
        Connect-ToAzureAccount
        # Set the Routing weight of secondary connection to 20 and primary connection to 30
        Set-VpnConnectionWeight -ConnectionName $PrimaryERConnectionName -ResourceGroupName $ResourceGroup -RoutingWeight 30
        Set-VpnConnectionWeight -ConnectionName $SecondaryERConnectionName -ResourceGroupName $ResourceGroup -RoutingWeight 20
        Write-Host "$($currentTime): Ping to $PrimaryRouteIpAddress succeed. Set the Routing weight of secondary connection to 20 and primary connection to 30"
        sleep -seconds 50
        break  # break only the inner while loop, so that it will return to the outer while loop
      }
    }
  }
}
