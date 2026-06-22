param(
    [string]$Endpoint = "https://fra.cloud.appwrite.io/v1",
    [string]$ProjectId = "6a319781003dd693dfd5",
    [string]$DatabaseId = "stadium_booking"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:APPWRITE_API_KEY)) {
    throw "APPWRITE_API_KEY is not set. Set it in the shell before running this script."
}

$Headers = @{
    "Content-Type"                 = "application/json"
    "X-Appwrite-Response-Format"   = "1.9.5"
    "X-Appwrite-Project"           = $ProjectId
    "X-Appwrite-Key"               = $env:APPWRITE_API_KEY
}

function Invoke-Appwrite {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Body
    )

    $uri = "$Endpoint$Path"
    $jsonBody = $null

    if ($Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 10
    }

    try {
        if ($jsonBody) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers -Body $jsonBody
        }

        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers
    }
    catch {
        $response = $_.Exception.Response

        if ($null -eq $response) {
            throw
        }

        $statusCode = [int]$response.StatusCode
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()

        if ($statusCode -eq 404) {
            return $null
        }

        if ($statusCode -eq 409) {
            return @{ alreadyExists = $true }
        }

        throw "Appwrite request failed ($statusCode) $Method $Path $errorBody"
    }
}

function Ensure-Database {
    param([string]$Id, [string]$Name)

    $existing = Invoke-Appwrite -Method "GET" -Path "/databases/$Id"
    if ($existing) {
        Write-Host "Database exists: $Id"
        return
    }

    Invoke-Appwrite -Method "POST" -Path "/databases" -Body @{
        databaseId = $Id
        name       = $Name
        enabled    = $true
    } | Out-Null

    Write-Host "Created database: $Id"
}

function Ensure-Collection {
    param(
        [string]$Id,
        [string]$Name,
        [string[]]$Permissions,
        [bool]$DocumentSecurity = $false
    )

    $existing = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/$Id"
    if ($existing) {
        Write-Host "Table exists: $Id"
        Invoke-Appwrite -Method "PUT" -Path "/databases/$DatabaseId/collections/$Id" -Body @{
            name             = $Name
            permissions      = $Permissions
            documentSecurity = $DocumentSecurity
            enabled          = $true
        } | Out-Null
        Write-Host "Updated table settings: $Id"
        return
    }

    Invoke-Appwrite -Method "POST" -Path "/databases/$DatabaseId/collections" -Body @{
        collectionId     = $Id
        name             = $Name
        permissions      = $Permissions
        documentSecurity = $DocumentSecurity
        enabled          = $true
    } | Out-Null

    Write-Host "Created table: $Id"
}

function Wait-Attribute {
    param([string]$CollectionId, [string]$Key)

    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $attribute = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/$Key"

        if ($attribute -and $attribute.status -eq "available") {
            return
        }

        if ($attribute -and $attribute.status -eq "failed") {
            throw "Attribute failed: $CollectionId.$Key"
        }

        Start-Sleep -Seconds 1
    }

    throw "Timed out waiting for attribute: $CollectionId.$Key"
}

function Ensure-Attribute {
    param(
        [string]$CollectionId,
        [string]$Kind,
        [hashtable]$Definition
    )

    $key = $Definition.key
    $existing = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/$key"

    if ($existing) {
        Write-Host "Column exists: $CollectionId.$key"
        Wait-Attribute -CollectionId $CollectionId -Key $key
        return
    }

    Invoke-Appwrite -Method "POST" -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/$Kind" -Body $Definition | Out-Null
    Write-Host "Created column: $CollectionId.$key"
    Wait-Attribute -CollectionId $CollectionId -Key $key
}

function Ensure-Index {
    param(
        [string]$CollectionId,
        [string]$Key,
        [string[]]$Attributes
    )

    $existing = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/$CollectionId/indexes/$Key"
    if ($existing) {
        Write-Host "Index exists: $CollectionId.$Key"
        return
    }

    Invoke-Appwrite -Method "POST" -Path "/databases/$DatabaseId/collections/$CollectionId/indexes" -Body @{
        key        = $Key
        type       = "key"
        attributes = $Attributes
    } | Out-Null

    Write-Host "Created index: $CollectionId.$Key"
}

function Ensure-BookedSlotMarkersFromBookings {
    $created = 0

    $result = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/bookings/documents"

    if ($null -eq $result -or $null -eq $result.documents -or $result.documents.Count -eq 0) {
        Write-Host "Created booked slot markers from existing bookings: 0"
        return
    }

    foreach ($document in $result.documents) {
        if ($document.data.status -ne "active") {
            continue
        }

        $slotId = $document.data.slotId
        $stadiumId = $document.data.stadiumId
        $dayDate = $document.data.dayDate
        $slotTime = $document.data.slotTime

        if ([string]::IsNullOrWhiteSpace($slotId) -or
            [string]::IsNullOrWhiteSpace($stadiumId) -or
            [string]::IsNullOrWhiteSpace($dayDate) -or
            [string]::IsNullOrWhiteSpace($slotTime)) {
            continue
        }

        $existing = Invoke-Appwrite -Method "GET" -Path "/databases/$DatabaseId/collections/booked_slots/documents/$slotId"
        if ($existing) {
            continue
        }

        $userId = $document.data.userId
        $permissions = @('read("users")')
        if (-not [string]::IsNullOrWhiteSpace($userId)) {
            $permissions += "update(`"user:$userId`")"
            $permissions += "delete(`"user:$userId`")"
        }

        Invoke-Appwrite -Method "POST" -Path "/databases/$DatabaseId/collections/booked_slots/documents" -Body @{
            documentId  = $slotId
            data        = @{
                stadiumId = $stadiumId
                dayDate   = $dayDate
                slotTime  = $slotTime
                status    = "active"
            }
            permissions = $permissions
        } | Out-Null
        $created++
    }

    Write-Host "Created booked slot markers from existing bookings: $created"
}

Ensure-Database -Id $DatabaseId -Name "Stadium Booking"

Ensure-Collection -Id "stadiums" -Name "Stadiums" -Permissions @('read("any")') -DocumentSecurity $false
Ensure-Collection -Id "slots" -Name "Slots" -Permissions @('read("any")') -DocumentSecurity $false
Ensure-Collection -Id "booked_slots" -Name "Booked Slots" -Permissions @('create("users")') -DocumentSecurity $true
Ensure-Collection -Id "bookings" -Name "Bookings" -Permissions @('create("users")') -DocumentSecurity $true
Ensure-Collection -Id "favorites" -Name "Favorites" -Permissions @('create("users")') -DocumentSecurity $true

Ensure-Attribute -CollectionId "stadiums" -Kind "string" -Definition @{ key = "name"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "stadiums" -Kind "string" -Definition @{ key = "location"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "stadiums" -Kind "float" -Definition @{ key = "rating"; required = $true; array = $false }
Ensure-Attribute -CollectionId "stadiums" -Kind "integer" -Definition @{ key = "price"; required = $true; array = $false }
Ensure-Attribute -CollectionId "stadiums" -Kind "string" -Definition @{ key = "available"; size = 64; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "stadiums" -Kind "string" -Definition @{ key = "icon"; size = 64; required = $true; array = $false; encrypt = $false }

Ensure-Attribute -CollectionId "slots" -Kind "string" -Definition @{ key = "stadiumId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "slots" -Kind "string" -Definition @{ key = "date"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "slots" -Kind "string" -Definition @{ key = "label"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "slots" -Kind "string" -Definition @{ key = "time"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "slots" -Kind "boolean" -Definition @{ key = "isBooked"; required = $true; array = $false }

Ensure-Attribute -CollectionId "booked_slots" -Kind "string" -Definition @{ key = "stadiumId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "booked_slots" -Kind "string" -Definition @{ key = "dayDate"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "booked_slots" -Kind "string" -Definition @{ key = "slotTime"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "booked_slots" -Kind "string" -Definition @{ key = "status"; size = 32; required = $true; array = $false; encrypt = $false }

Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "userId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "stadiumId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "slotId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "stadiumName"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "location"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "float" -Definition @{ key = "rating"; required = $true; array = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "integer" -Definition @{ key = "price"; required = $true; array = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "icon"; size = 64; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "dayLabel"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "dayDate"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "slotTime"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "string" -Definition @{ key = "status"; size = 32; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "bookings" -Kind "datetime" -Definition @{ key = "createdAt"; required = $true; array = $false }

Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "userId"; size = 36; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "stadiumId"; size = 64; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "name"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "location"; size = 128; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "float" -Definition @{ key = "rating"; required = $true; array = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "integer" -Definition @{ key = "price"; required = $true; array = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "available"; size = 64; required = $true; array = $false; encrypt = $false }
Ensure-Attribute -CollectionId "favorites" -Kind "string" -Definition @{ key = "icon"; size = 64; required = $true; array = $false; encrypt = $false }

Ensure-Index -CollectionId "slots" -Key "stadiumId_index" -Attributes @("stadiumId")
Ensure-Index -CollectionId "booked_slots" -Key "stadium_status_index" -Attributes @("stadiumId", "status")
Ensure-Index -CollectionId "booked_slots" -Key "slot_status_index" -Attributes @("stadiumId", "dayDate", "slotTime", "status")
Ensure-Index -CollectionId "bookings" -Key "userId_index" -Attributes @("userId")
Ensure-Index -CollectionId "bookings" -Key "slotId_index" -Attributes @("slotId")
Ensure-Index -CollectionId "bookings" -Key "status_index" -Attributes @("status")
Ensure-Index -CollectionId "bookings" -Key "stadium_slot_index" -Attributes @("stadiumId", "dayDate", "slotTime", "status")
Ensure-Index -CollectionId "favorites" -Key "userId_index" -Attributes @("userId")
Ensure-Index -CollectionId "favorites" -Key "stadiumId_index" -Attributes @("stadiumId")

Ensure-BookedSlotMarkersFromBookings

Write-Host "Appwrite database setup complete."
