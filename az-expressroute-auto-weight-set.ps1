function Connect-ToAzureAccount {
  $Cred = [PSCustomObject]@{
    TenantId = "<tenand_id>"
    SubscriptionId = "<subscription_id>"
    AplicationId ="<application_id>"
    ApplicationSecret = ConvertTo-SecureString "<application_secret>" -AsPlainText -Force
  }
  $psCred = New-Object System.Management.Automation.PSCredential($Cred.AplicationId , $Cred.ApplicationSecret)
  Connect-AzAccount -ServicePrincipal -Credential $psCred -Tenant $Cred.TenantId -Subscription $Cred.SubscriptionId
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
    Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $ConnectionName -Force
  }
  catch {
    if ($_.Exception.Message -like "*AuthorizationFailed*") {
      Connect-ToAzureAccount
      $ConnectionInfo = Get-AzVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $ResourceGroupName
      $ConnectionInfo.RoutingWeight = $RoutingWeight
      Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $ConnectionName -Force
    } else {
      throw $_
    }
  }
}


$PrimaryRouteIpAddress = "<primary_route_ip_address>"
$PrimaryERConnectionName = "<primary_er_connection_name>"
$SecondaryERConnectionName = "<secondary_er_connection_name>"

# Monitor the primary route IP address, if it is not reachable, set the Routing weight of secondary connection to 30 and primary connection to 20
while ($true) {
  sleep -seconds 5
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
    Write-Host "$($currentTime): Ping to $OnpremIpAddress failed. Set the Routing weight of secondary connection to 30 and primary connection to 20"

    # Monitor the primary route IP address, if it is reachable, set the Routing weight of secondary connection to 20 and primary connection to 30
    while ($true) {
      sleep -seconds 5
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
        Write-Host "$($currentTime): Ping to $OnpremIpAddress succeed. Set the Routing weight of secondary connection to 20 and primary connection to 30"
        break  # break only the inner while loop, so that it will return to the outer while loop
      }
    }
  }
}
