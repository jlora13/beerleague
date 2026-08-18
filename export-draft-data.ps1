# Export/Import draft board data
# Usage:
#   .\export-draft-data.ps1 -Export
#   .\export-draft-data.ps1 -Import -InputDir ".\draft-data-export"

param(
    [switch]$Export,
    [switch]$Import,
    [string]$InputDir = ".\draft-data-export",
    [string]$OutputDir = ".\draft-data-export",
    [string]$OrgAlias = "beerleagueprod"
)

if ($Export) {
    Write-Host "=== EXPORTING DRAFT BOARD DATA ==="

    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    # Export Draft Seasons
    Write-Host "Exporting Draft Seasons..."
    sf data query --query "SELECT Id, Name, Year__c FROM Draft_Season__c ORDER BY Year__c DESC" --target-org $OrgAlias --csv > "$OutputDir/draft_seasons.csv"

    # Export League Members
    Write-Host "Exporting League Members..."
    sf data query --query "SELECT Id, Name, Draft_Order__c FROM League_Member__c ORDER BY Draft_Order__c ASC" --target-org $OrgAlias --csv > "$OutputDir/league_members.csv"

    # Export League Member Seasons
    Write-Host "Exporting League Member Seasons..."
    sf data query --query "SELECT Id, League_Member__c, League_Member__r.Name, Draft_Season__c, Draft_Season__r.Name, Draft_Order__c FROM League_Member_Season__c ORDER BY Draft_Season__r.Year__c DESC, Draft_Order__c ASC" --target-org $OrgAlias --csv > "$OutputDir/league_member_seasons.csv"

    # Export Players (Contacts)
    Write-Host "Exporting Players..."
    sf data query --query "SELECT Id, FirstName, LastName, Team__c, Position__c, Overall_Rank__c, Position_Rank__c, Bye__c, Draft_Season__c, Is_Drafted__c FROM Contact WHERE Draft_Season__c != null ORDER BY Draft_Season__c, Overall_Rank__c" --target-org $OrgAlias --csv > "$OutputDir/players.csv"

    # Export Draft Picks
    Write-Host "Exporting Draft Picks..."
    sf data query --query "SELECT Id, Overall_Pick__c, Round__c, Pick_In_Round__c, League_Member__c, League_Member__r.Name, Player__c, Player__r.FirstName, Player__r.LastName, Is_Picked__c, Is_Upside_Down__c, Traded_To__c, Traded_To__r.Name, Trade_Notes__c, Draft_Season__c FROM Draft_Pick__c ORDER BY Draft_Season__c, Overall_Pick__c" --target-org $OrgAlias --csv > "$OutputDir/draft_picks.csv"

    Write-Host ""
    Write-Host "✓ Export complete! Files saved to $OutputDir/"
    Write-Host ""
    Write-Host "Files created:"
    Get-ChildItem $OutputDir | ForEach-Object { Write-Host "  - $($_.Name)" }
}

elseif ($Import) {
    Write-Host "=== IMPORTING DRAFT BOARD DATA ==="
    Write-Host "Target Org: $OrgAlias"
    Write-Host "Input Dir: $InputDir"
    Write-Host ""

    # Verify files exist
    $requiredFiles = @("draft_seasons.csv", "league_members.csv", "league_member_seasons.csv", "players.csv", "draft_picks.csv")
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path "$InputDir/$file")) {
            Write-Error "Missing file: $InputDir/$file"
            exit 1
        }
    }

    # Generate Apex import commands and execute
    Write-Host "Executing import in Salesforce..."

    $apexCode = @"
// Import draft board data
List<List<String>> draftSeasonsCsv = new List<List<String>>();
List<List<String>> leagueMembersCsv = new List<List<String>>();
List<List<String>> leagueMemberSeasonsCsv = new List<List<String>>();
List<List<String>> playersCsv = new List<List<String>>();
List<List<String>> draftPicksCsv = new List<List<String>>();

// Load and parse CSVs...
// (Note: This would require reading files, which Apex can't do directly)
// Alternative: Use the provided import commands below

System.debug('Import initiated. Use DraftBoardImport class methods.');
"@

    Write-Host ""
    Write-Host "NEXT STEP: Execute the import in Salesforce"
    Write-Host ""
    Write-Host "Option 1 (Recommended): Use Data Import Wizard or third-party tools"
    Write-Host "Option 2: Manually import each CSV in order:"
    Write-Host "  1. Draft Seasons"
    Write-Host "  2. League Members"
    Write-Host "  3. League Member Seasons"
    Write-Host "  4. Players (Contacts)"
    Write-Host "  5. Draft Picks"
    Write-Host ""
    Write-Host "CSV files are ready in: $InputDir"
}

else {
    Write-Host "Usage:"
    Write-Host "  .\export-draft-data.ps1 -Export [-OutputDir path] [-OrgAlias alias]"
    Write-Host "  .\export-draft-data.ps1 -Import [-InputDir path] [-OrgAlias alias]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\export-draft-data.ps1 -Export"
    Write-Host "  .\export-draft-data.ps1 -Import -InputDir "".\my-backup"""
}
