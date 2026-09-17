# Beer League Draft Board - New Org Setup Script
# Automates complete setup of Beer League Draft Board in a new org
# Usage: .\setup-new-org.ps1 -TargetOrg "org-alias" -Action "full" | "deploy" | "config" | "data"

param(
    [Parameter(Mandatory=$false)]
    [string]$TargetOrg = "beerleague",

    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "deploy", "config", "data", "seed", "export", "import")]
    [string]$Action = "full",

    [Parameter(Mandatory=$false)]
    [string]$DataDir = ".\draft-data-export",

    [Parameter(Mandatory=$false)]
    [string]$ImportDir = ".\draft-data-export"
)

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "  $Title"
    Write-Host "==============================================="
    Write-Host ""
}

function Test-OrgAuth {
    param([string]$Org)
    $result = sf org list --json | ConvertFrom-Json
    $found = $result.result.nonScratchOrgs | Where-Object { $_.alias -eq $Org }
    if ($null -eq $found) {
        Write-Error "Organization '$Org' not found. Authenticate first: sf org login web --alias $Org"
        exit 1
    }
    Write-Host "✓ Organization authenticated: $Org"
}

function Deploy-Metadata {
    Write-Section "Step 1: Deploying Metadata"
    Write-Host "Deploying all code, objects, and components..."

    $result = sf project deploy start --target-org $TargetOrg --wait 10
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Metadata deployed successfully"
    } else {
        Write-Error "Metadata deployment failed"
        exit 1
    }
}

function Create-Config {
    Write-Section "Step 2: Creating Draft Board Configuration"
    Write-Host "To enable features, create Draft_Board_Config__mdt record in Salesforce:"
    Write-Host ""
    Write-Host "  1. Navigate to Setup → Custom Metadata Types"
    Write-Host "  2. Click 'Draft Board Config'"
    Write-Host "  3. Create new record (or edit existing 'Default Config'):"
    Write-Host ""
    Write-Host "     Label: Default Config"
    Write-Host "     API Name: Default_Config"
    Write-Host "     Enable_Timer__c: ☑ checked"
    Write-Host "     Timer_Minutes__c: 5"
    Write-Host "     Timer_Seconds__c: 0"
    Write-Host "     Enable_Spell_Checker__c: ☑ checked"
    Write-Host "     Enable_Sequential_Order__c: ☐ unchecked"
    Write-Host ""
    Write-Host "⚠ This must be created manually in Setup → Custom Metadata Types"
    Write-Host ""
    Write-Host "Press Enter once you've created the record to continue..."
    Read-Host
}

function Create-BaseData {
    Write-Section "Step 3: Creating Base Data (League Members & Seasons)"
    Write-Host "Creating sample League Members (12 teams) and Draft Seasons..."

    $apexCode = @"
// Create League Members
List<League_Member__c> members = new List<League_Member__c>();
String[] teamNames = new String[]{'Frankie', 'Max', 'Jake', 'Jesse', 'Connor', 'Justin', 'Nick', 'Scott', 'Jared', 'Jack', 'Mike', 'Chris'};
for (Integer i = 0; i < teamNames.size(); i++) {
    members.add(new League_Member__c(
        Name = teamNames[i],
        Draft_Order__c = i + 1
    ));
}
insert members;
System.debug('Created ' + members.size() + ' League Members');

// Create Draft Season
Draft_Season__c season = new Draft_Season__c(
    Name = '2026 Season',
    Year__c = 2026
);
insert season;
System.debug('Created Draft Season: ' + season.Id);

// Create League Member Season records
List<League_Member_Season__c> memberSeasons = new List<League_Member_Season__c>();
for (League_Member__c m : [SELECT Id, Draft_Order__c FROM League_Member__c ORDER BY Draft_Order__c ASC]) {
    memberSeasons.add(new League_Member_Season__c(
        League_Member__c = m.Id,
        Draft_Season__c = season.Id,
        Draft_Order__c = m.Draft_Order__c
    ));
}
insert memberSeasons;
System.debug('Created ' + memberSeasons.size() + ' League Member Season records');
"@

    $tempFile = New-TemporaryFile
    $apexCode | Set-Content -Path $tempFile.FullName

    Write-Host "Executing Apex setup code..."
    sf apex run --file $tempFile.FullName --target-org $TargetOrg

    Remove-Item $tempFile
    Write-Host "✓ Base data created"
}

function Seed-Picks {
    Write-Section "Step 4: Seeding Draft Picks"
    Write-Host "Generating 240 draft pick records (12 teams × 20 rounds)..."

    $apexCode = @"
Id seasonId = [SELECT Id FROM Draft_Season__c ORDER BY Year__c DESC LIMIT 1].Id;
DraftBoardSetup.seedPicksForSeason(seasonId);
"@

    $tempFile = New-TemporaryFile
    $apexCode | Set-Content -Path $tempFile.FullName

    Write-Host "Seeding picks for current season..."
    sf apex run --file $tempFile.FullName --target-org $TargetOrg

    Remove-Item $tempFile
    Write-Host "✓ Draft picks seeded"
}

function Export-Data {
    Write-Section "Exporting Draft Board Data"
    Write-Host "Exporting all draft board data to CSV files..."
    Write-Host "Output directory: $DataDir"
    Write-Host ""

    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir | Out-Null
    }

    Write-Host "Exporting Draft Seasons..."
    sf data query --query "SELECT Id, Name, Year__c FROM Draft_Season__c ORDER BY Year__c DESC" --target-org $TargetOrg --csv | Out-File "$DataDir/draft_seasons.csv" -Encoding UTF8

    Write-Host "Exporting League Members..."
    sf data query --query "SELECT Id, Name, Draft_Order__c FROM League_Member__c ORDER BY Draft_Order__c ASC" --target-org $TargetOrg --csv | Out-File "$DataDir/league_members.csv" -Encoding UTF8

    Write-Host "Exporting League Member Seasons..."
    sf data query --query "SELECT Id, League_Member__c, League_Member__r.Name, Draft_Season__c, Draft_Season__r.Name, Draft_Order__c FROM League_Member_Season__c ORDER BY Draft_Season__r.Year__c DESC, Draft_Order__c ASC" --target-org $TargetOrg --csv | Out-File "$DataDir/league_member_seasons.csv" -Encoding UTF8

    Write-Host "Exporting Players..."
    sf data query --query "SELECT Id, FirstName, LastName, Team__c, Position__c, Overall_Rank__c, Position_Rank__c, Bye__c, Draft_Season__c, Is_Drafted__c FROM Contact WHERE Draft_Season__c != null ORDER BY Draft_Season__c, Overall_Rank__c" --target-org $TargetOrg --csv | Out-File "$DataDir/players.csv" -Encoding UTF8

    Write-Host "Exporting Draft Picks..."
    sf data query --query "SELECT Id, Overall_Pick__c, Round__c, Pick_In_Round__c, League_Member__c, League_Member__r.Name, Player__c, Player__r.FirstName, Player__r.LastName, Is_Picked__c, Is_Upside_Down__c, Traded_To__c, Traded_To__r.Name, Trade_Notes__c, Draft_Season__c FROM Draft_Pick__c ORDER BY Draft_Season__c, Overall_Pick__c" --target-org $TargetOrg --csv | Out-File "$DataDir/draft_picks.csv" -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Export complete!"
    Write-Host ""
    Write-Host "Files created in $DataDir :"
    Get-ChildItem $DataDir -Filter "*.csv" | ForEach-Object { Write-Host "  - $($_.Name)" }
}

function Import-Data {
    Write-Section "Importing Draft Board Data"
    Write-Host "Importing data from CSV files in: $ImportDir"
    Write-Host ""

    # Check required files
    $requiredFiles = @("draft_seasons.csv", "league_members.csv", "league_member_seasons.csv", "players.csv", "draft_picks.csv")
    $allFilesPresent = $true

    foreach ($file in $requiredFiles) {
        $path = Join-Path $ImportDir $file
        if (Test-Path $path) {
            Write-Host "✓ Found $file"
        } else {
            Write-Host "✗ Missing $file"
            $allFilesPresent = $false
        }
    }

    if (-not $allFilesPresent) {
        Write-Error "Some required CSV files are missing!"
        exit 1
    }

    Write-Host ""
    Write-Host "Using Salesforce Data Cloud for import (via CLI)..."
    Write-Host "This requires manual import or a third-party data loader tool."
    Write-Host ""
    Write-Host "Recommended: Use Salesforce Data Loader or similar tool to import in this order:"
    Write-Host "  1. draft_seasons.csv"
    Write-Host "  2. league_members.csv"
    Write-Host "  3. league_member_seasons.csv"
    Write-Host "  4. players.csv (Contact records)"
    Write-Host "  5. draft_picks.csv"
    Write-Host ""
    Write-Host "CSV files are located in: $ImportDir"
}

# Main execution
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗"
Write-Host "║   Beer League Draft Board - New Org Setup                 ║"
Write-Host "╚═══════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Target Organization: $TargetOrg"
Write-Host "Action: $Action"
Write-Host ""

# Authenticate with target org
Test-OrgAuth -Org $TargetOrg

switch ($Action) {
    "full" {
        Deploy-Metadata
        Create-Config
        Create-BaseData
        Seed-Picks
        Write-Section "Setup Complete!"
        Write-Host "✓ All setup steps completed successfully!"
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  1. Log into your Salesforce org"
        Write-Host "  2. Navigate to the 'Beer League Draft' app"
        Write-Host "  3. Load player data (Contacts) if needed"
        Write-Host "  4. Start drafting!"
    }

    "deploy" {
        Deploy-Metadata
    }

    "config" {
        Create-Config
    }

    "data" {
        Create-BaseData
        Seed-Picks
    }

    "seed" {
        Seed-Picks
    }

    "export" {
        Export-Data
    }

    "import" {
        Import-Data
    }
}

Write-Host ""
Write-Host "✓ Script completed"
