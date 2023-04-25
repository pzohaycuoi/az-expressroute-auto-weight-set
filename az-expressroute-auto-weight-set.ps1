[CmdletBinding()]
param (
  [Parameter()]
  [TypeName("System.String")]
  $OnpremIpAddress,

  [Parameter()]
  [TypeName("System.String")]
  $PrimaryERConnectionName,

  [Parameter()]
  [TypeName("System.String")]
  $SecondaryERConnectionName,

  [Parameter()]
  [TypeName("System.String")]
  $ExpressRouteGatewayName
)

# Ping to the on-prem IP address in a loop with interval of 5 seconds
# If ping is not successful set the Routing weight of secondary connection to 100 and primary connection to 0

Connect-AzAccount

while ($true) {
  # Ping the on-prem IP address
  $ping = Test-NetConnection $OnpremIpAddress -Count 5
  if ($ping -eq $false) {
    # If ping is not successful
    # Get the current time
    $currentTime = Get-Date
    # Set the Routing weight of secondary connection to 100 and primary connection to 0
    Set-AzExpressRouteConnection -Name $PrimaryERConnectionName -ExpressRouteGatewayName $ExpressRouteGatewayName -RoutingWeight 20
    Set-AzExpressRouteConnection -Name $SecondaryERConnectionName -ExpressRouteGatewayName $ExpressRouteGatewayName -RoutingWeight 30
    Write-Host "$($currentTime): Ping to $OnpremIpAddress failed. Set the Routing weight of secondary connection to 30 and primary connection to 20"
  }
}
