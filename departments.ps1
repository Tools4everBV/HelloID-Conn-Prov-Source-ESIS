
########################################################################
# HelloID-Conn-Prov-Source-ESIS-Departments
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
        $Brin
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

        $departmentList = [System.Collections.Generic.list[object]]::new()
        $departmentListBrin = [System.Collections.Generic.list[object]]::new()

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
        $departmentXMLList = $rawResponse.vestigingen.vestiging
        Write-Verbose 'Format XML response to HelloID departments'
        foreach ($department in $departmentXMLList ) {
            $departmentObject = @{
                DisplayName = $department.naam
                ExternalId  = $department.key
                Brin        = $brin
            }
            $departmentListBrin.add($departmentObject)
        }

        Write-Verbose "Found [$($departmentListBrin.count)] departments for Brin number: [$brin] for SchoolYear [$schoolYear]"
        $departmentList.AddRange($departmentListBrin);

        Write-Verbose "[Full import] importing [$($departmentList.count)] departments"
        Write-Output ($departmentList | ConvertTo-Json -Depth 10)
    }
    catch {
        Write-Verbose "Error : $($_)" -Verbose
    }
}

try {
    Import-ESISCertificate -CertificatePath $config.certPath  -CertificatePassword $config.certPassword

    foreach ($auth in $configAuth) {
        Get-ESISBrinData -Autorisatiesleutel $auth.key -Brin $auth.brin
    }
}
catch {
    Write-Verbose "Error : $($_)" -Verbose
}