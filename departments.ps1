########################################################################
# HelloID-Conn-Prov-Source-ESIS-Departments
#
# Version: 1.0.0
########################################################################
$VerbosePreference = "Continue"

$config = $configuration | ConvertFrom-Json

try {
    [xml]$body = @'
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <soap:Header>
        <autorisatie xmlns="http://www.edustandaard.nl/leerresultaten/2/autorisatie">
            <autorisatiesleutel>""</autorisatiesleutel>
            <klantcode>""</klantcode>
            <klantnaam>""</klantnaam>
        </autorisatie>
    </soap:Header>
    <soap:Body>
        <leerlinggegevens_verzoek xmlns="http://www.edustandaard.nl/leerresultaten/2/leerlinggegevens">
            <schooljaar>""</schooljaar>
            <brincode>""</brincode>
            <schoolkey>""</schoolkey>
            <xsdversie>""</xsdversie>
            <dependancecode>00</dependancecode>
        </leerlinggegevens_verzoek>
    </soap:Body>
</soap:Envelope>
'@

    $body.Envelope.Header.autorisatie.autorisatiesleutel = "$($config.autorisatiesleutel)"
    $body.Envelope.Header.autorisatie.klantcode = "$($config.klantcode)"
    $body.Envelope.Header.autorisatie.klantnaam = "$($config.klantnaam)"
    $body.Envelope.Body.leerlinggegevens_verzoek.xsdversie = "$($xsdversie)"
    if ([string]::IsNullOrEmpty($config.dependancecode)) {
        $body.Envelope.Body.leerlinggegevens_verzoek.dependancecode = "$($config.dependancecode)"
    }
    $body.Envelope.Body.leerlinggegevens_verzoek.schoolkey = "$($config.klantcode)"
    if ($null -eq $config.brinIdentifiers) {
        throw 'No brin identifiers provided in the configuration settings'
    }
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($config.certpath, $config.certpassword, 'UserKeySet')
    $headers = @{
        SoapAction = 'HaalLeerlinggegevens'
    }
    $departmentList = [System.Collections.Generic.list[object]]::new()

    $brinNumbers = [array]$config.brinIdentifiers.split(',') | ForEach-Object { $_.trim(' ') }
    foreach ($brin in $brinNumbers) {
        Write-Verbose "Add Brin [$brin] number to Web Reqeust "
        $body.Envelope.Body.leerlinggegevens_verzoek.brincode = $brin
        $deparmentListBrin = [System.Collections.Generic.list[object]]::new()


        $spatWebrequest = @{
            Method          = "POST"
            Uri             = $config.BaseUrl
            Certificate     = $cert
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
            $deparmentListBrin.add($departmentObject)
        }

        Write-Verbose "Found [$($deparmentListBrin.count)] departments for Brin number: [$brin] for SchoolYear [$schoolYear]"
        $departmentList.AddRange($deparmentListBrin);
    }
    Write-Verbose "[Full import] importing [$($departmentList.count)] departments"
    Write-Output ($departmentList | ConvertTo-Json -Depth 10)
} catch {
    Write-Verbose "Error : $($_)" -Verbose
}
