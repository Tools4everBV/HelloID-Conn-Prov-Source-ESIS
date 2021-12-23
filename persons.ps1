########################################################################
# HelloID-Conn-Prov-Source-ESIS-Persons
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
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($config.certpath, $config.certpassword, 'UserKeySet')
    $headers = @{
        SoapAction = 'HaalLeerlinggegevens'
    }
    $personList = [System.Collections.Generic.list[object]]::new()

    if ($null -eq $config.brinIdentifiers) {
        throw 'No brin identifiers provided in the configuration settings'
    }
    $brinNumbers = [array]$config.brinIdentifiers.split(',') | ForEach-Object { $_.trim(' ') }
    foreach ($brin in $brinNumbers) {
        Write-Verbose "Add Brin [$brin] number to Web Reqeust "
        $body.Envelope.Body.leerlinggegevens_verzoek.brincode = $brin
        $personListBrin = [System.Collections.Generic.list[object]]::new()


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
        $studentList = $rawResponse.leerlingen.leerling
        $groupList = $rawResponse.groepen.groep
        $subGroupList = $rawResponse.groepen.samengestelde_groep
        $schoolYear = $rawResponse.school.schooljaar

        $groupListGrouped = $groupList | Group-Object -Property 'key' -AsHashTable -AsString
        $subGroupListGrouped = $subGroupList | Group-Object -Property 'key' -AsHashTable -AsString

        Write-Verbose 'Format XML response to HelloID Persons and Contracts'
        foreach ($student in $studentList ) {
            # Format Student To HelloID person
            $person = @{
                DisplayName   = ($student.roepnaam + ' ' + $student.achternaam).trim(' ')
                ExternalId    = $student.key
                key           = $student.key
                achternaam    = $student.achternaam
                roepnaam      = $student.roepnaam
                geboortedatum = $student.geboortedatum
                geslacht      = $student.geslacht
                jaargroep     = $student.jaargroep
                vestiging     = $student.vestiging.key
                Brin          = $brin
            }

            # Format Group To HelloID contact
            $contractList = [System.Collections.Generic.list[object]]::new()
            if ($null -ne $student.groep) {
                $groupSelected = $groupListGrouped[$student.groep.key]
                $groupObject = @{
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
                $groupObject = @{
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
            $personListBrin.add($person)
        }

        Write-Verbose "Found [$($personListBrin.count)] persons for Brin number: [$brin] for SchoolYear [$schoolYear]"
        $personList.AddRange($personListBrin);
    }
    Write-Verbose "[Full import] importing [$($personList.count)] persons"
    Write-Output ($personList | ConvertTo-Json -Depth 10)
} catch {
    Write-Verbose "Error : $($_)" -Verbose
}
