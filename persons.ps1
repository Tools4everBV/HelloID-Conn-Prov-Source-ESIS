########################################################################
# HelloID-Conn-Prov-Source-ESIS-Persons
#
# Version: 2.0.0
#
# Connector for ESIS (Rovict) based in the API
# Supports multiple schools (BRIN + key)
# Requires json body as config 'AuthBrinKeys' field containing the brin and key
# AuthBrinKeys: '[ { "brin": "12345", "key": "abcde" } ]'
# Supports school dependences (sub locations)
########################################################################
$VerbosePreference = "Continue"

# Example configuration
# $configuration = '{ "BaseUrl": "https://12345.rovictonline.nl/uwlr2.2.svc", "AuthBrinKeys": "[ { } ]"'

$config = $configuration | ConvertFrom-Json
$configAuth = $config.AuthBrinKeys | ConvertFrom-Json

function Import-ESISCertificate {
    [Cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The path to the pfx certificate, it must be accessible by the agent.")]
        $CertificatePath,

        [Parameter(Mandatory = $true)]
        $CertificatePassword
    )

    $cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2($config.certpath, $config.certpassword, 'UserKeySet')

    if ($cert.NotAfter -le (Get-Date)) {
        throw "Certificate has expired on $($cert.NotAfter)..."
    }
    $script:Certificate = $cert
}

function Get-ESISBrinData {
    [CmdletBinding()]
    param (
        [Alias("Param1")]
        [parameter(Mandatory = $true)]
        [string]
        $Autorisatiesleutel,

        [Alias("Param2")]
        [parameter(Mandatory = $true)]
        [string]
        $Brin,

        [parameter(Mandatory = $true)]
        [ref]
        $Data
    )

    try {
        if ([String]::IsNullOrEmpty($Brin)) {
            throw 'No brin identifier provided, aborting...'
        }

        if ([String]::IsNullOrEmpty($Autorisatiesleutel)) {
            throw 'No autorisatiesleutel provided, aborting...'
        }

        $dependanceCode = $Brin.Split(".")[1]
        $brinCode = $Brin.Split(".")[0]

        if ([String]::IsNullOrEmpty($brinCode)) {
            throw 'No brin code provided, aborting...'
        }

        if ([String]::IsNullOrEmpty($dependanceCode)) {
            throw 'No dependance code provided, aborting...'
        }

        [xml]$body = @'
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
xmlns:au="http://www.edustandaard.nl/leerresultaten/2/autorisatie"
xmlns:le="http://www.edustandaard.nl/leerresultaten/2/leerlinggegevens"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="
    http://www.edustandaard.nl/leerresultaten/2/autorisatie ../Schemas/UWLR_Autorisatie_v2p2.xsd
    http://www.edustandaard.nl/leerresultaten/2/leerlinggegevens ../Schemas/UWLR_Leerlinggegevens_v2p2.xsd
    http://schemas.xmlsoap.org/soap/envelope/ ../Schemas/SOAP_Envelope.xsd">
<SOAP-ENV:Header>
    <au:autorisatie>
    <au:autorisatiesleutel></au:autorisatiesleutel>
    <au:klantcode></au:klantcode>
    <au:klantnaam></au:klantnaam>
    </au:autorisatie>
</SOAP-ENV:Header>
<SOAP-ENV:Body>
    <le:leerlinggegevens_verzoek>
    <le:schooljaar></le:schooljaar>
    <le:brincode></le:brincode>
    <le:dependancecode></le:dependancecode>
    <le:xsdversie>2.2</le:xsdversie>
    </le:leerlinggegevens_verzoek>
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
'@

        Write-Verbose "Add Brin [$Brin] to Web Request..."
        $body.Envelope.Header.autorisatie.autorisatiesleutel = "$($Autorisatiesleutel)"
        $body.Envelope.Header.autorisatie.klantcode = "$($config.klantcode)"
        $body.Envelope.Header.autorisatie.klantnaam = "$($config.klantnaam)"
        $body.Envelope.Body.leerlinggegevens_verzoek.schooljaar = ""
        $body.Envelope.Body.leerlinggegevens_verzoek.brincode = $brinCode
        $body.Envelope.Body.leerlinggegevens_verzoek.xsdversie = "$($config.xsdversie)"
        $body.Envelope.Body.leerlinggegevens_verzoek.dependancecode = "$($dependanceCode)"

        $headers = @{
            SoapAction = 'HaalLeerlinggegevens'
        }

        $body.InnerXml

        $spatWebrequest = @{
            Method          = "POST"
            Uri             = $config.BaseUrl
            Certificate     = $script:Certificate
            body            = $body.InnerXml
            ContentType     = 'text/xml; charset=utf-8'
            Headers         = $headers
            UseBasicParsing = $true
        }

        Write-Verbose "Invoking command [Invoke-WebRequest] to endpoint [$($spatWebrequest.Uri)] with SoapAction [$($headers.SoapAction)]"
        $response = Invoke-WebRequest  @spatWebrequest -Verbose:$false

        $rawResponse = ([xml]$response.content).Envelope.body.leerlinggegevens_antwoord.leerlinggegevens

        # Add list to variables
        $studentList = $rawResponse.leerlingen.leerling
        $groupList = $rawResponse.groepen.groep
        $subGroupList = $rawResponse.groepen.samengestelde_groep
        $schoolYear = $rawResponse.school.schooljaar

        $groupListGrouped = $groupList | Group-Object -Property 'key' -AsHashTable -AsString
        $subGroupListGrouped = $subGroupList | Group-Object -Property 'key' -AsHashTable -AsString

        Write-Verbose 'Format XML response to HelloID Persons and Contracts'
        foreach ($student in $studentList ) {
            # Format Student To HelloID person
            $person = [PSCustomObject]@{
                DisplayName   = ($student.roepnaam + ' ' + $student.achternaam).trim(' ')
                ExternalId    = $student.key
                key           = $student.key
                achternaam    = $student.achternaam
                voorvoegsel   = $student.voorvoegsel
                roepnaam      = $student.roepnaam
                geboortedatum = $student.geboortedatum
                geslacht      = $student.geslacht
                jaargroep     = $student.jaargroep
                vestiging     = $student.vestiging.key
                onderwijsnr   = $student."bsn_ondwnr-4"
                Brin          = $Brin
            }

            # Format Group To HelloID contact
            $contractList = [System.Collections.Generic.list[object]]::new()
            if ($null -ne $student.groep) {
                $groupSelected = $groupListGrouped[$student.groep.key]
                $groupObject = [PSCustomObject]@{
                    key       = $groupSelected.key
                    naam      = $groupSelected.naam
                    jaargroep = $groupSelected.jaargroep
                    GroupType = 'Group'
                    startDate = [datetime]"$($schoolYear.split('-')[0])-08-01"
                    endDate   = [datetime]"$($schoolYear.split('-')[1])-08-01"
                }
                $contractList.Add($groupObject)
            }

            # Format "sub" Group To HelloID contact
            foreach ($group in $student.samengestelde_groepen.samengestelde_groep) {
                $subGroupSelected = $subGroupListGrouped[$group.key]
                $groupObject = [PSCustomObject]@{
                    key          = $subGroupSelected.key
                    naam         = $subGroupSelected.naam
                    omschrijving = $subGroupSelected.omschrijving
                    GroupType    = 'SubGroup'
                    startDate    = [datetime]"$($schoolYear.split('-')[0])-08-01"
                    endDate      = [datetime]"$($schoolYear.split('-')[1])-08-01"
                }
                $contractList.Add($groupObject)
            }

            $person | Add-Member @{Contracts = $contractList } -Force
            [void]$Data.Value.add($person)
        }

        Write-Verbose "Found [$($studentList.count)] persons for Brin number: [$Brin] for SchoolYear [$schoolYear]"
    }
    catch {
        Write-Verbose "Error : $($_)" -Verbose
    }
}

try {
    Import-ESISCertificate -CertificatePath $config.certPath  -CertificatePassword $config.certPassword

    $data = [System.Collections.ArrayList]::new()

    foreach ($auth in $configAuth) {
        Get-ESISBrinData -Autorisatiesleutel $auth.key -Brin $auth.brin ([ref]$data)
    }

    $unique = $data | Sort-Object "ExternalId" -Unique

    Write-Verbose -Verbose $unique.count

    foreach ($person in $unique) {
        Write-Output ($person | ConvertTo-Json -Depth 3)
    }
}
catch {
    Write-Verbose "Error : $($_)" -Verbose
}