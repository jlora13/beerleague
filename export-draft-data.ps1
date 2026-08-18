# Export all draft board data to CSV files
# Usage: .\export-draft-data.ps1

$orgAlias = "beerleagueprod"
$outputDir = ".\draft-data-export"

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "Exporting draft board data to $outputDir..."

# Export Draft Seasons
Write-Host "Exporting Draft Seasons..."
sf data query --query "SELECT Id, Name, Year__c FROM Draft_Season__c ORDER BY Year__c DESC" --target-org $orgAlias --csv > "$outputDir/draft_seasons.csv"

# Export League Members
Write-Host "Exporting League Members..."
sf data query --query "SELECT Id, Name, Draft_Order__c FROM League_Member__c ORDER BY Draft_Order__c ASC" --target-org $orgAlias --csv > "$outputDir/league_members.csv"

# Export League Member Seasons
Write-Host "Exporting League Member Seasons..."
sf data query --query "SELECT Id, League_Member__c, League_Member__r.Name, Draft_Season__c, Draft_Season__r.Name, Draft_Order__c FROM League_Member_Season__c ORDER BY Draft_Season__r.Year__c DESC, Draft_Order__c ASC" --target-org $orgAlias --csv > "$outputDir/league_member_seasons.csv"

# Export Players (Contacts)
Write-Host "Exporting Players..."
sf data query --query "SELECT Id, FirstName, LastName, Team__c, Position__c, Overall_Rank__c, Position_Rank__c, Bye__c, Draft_Season__c, Is_Drafted__c FROM Contact WHERE Draft_Season__c != null ORDER BY Draft_Season__c, Overall_Rank__c" --target-org $orgAlias --csv > "$outputDir/players.csv"

# Export Draft Picks
Write-Host "Exporting Draft Picks..."
sf data query --query "SELECT Id, Overall_Pick__c, Round__c, Pick_In_Round__c, League_Member__c, League_Member__r.Name, Player__c, Player__r.FirstName, Player__r.LastName, Is_Picked__c, Is_Upside_Down__c, Traded_To__c, Traded_To__r.Name, Trade_Notes__c, Draft_Season__c FROM Draft_Pick__c ORDER BY Draft_Season__c, Overall_Pick__c" --target-org $orgAlias --csv > "$outputDir/draft_picks.csv"

Write-Host "Export complete! Files saved to $outputDir/"
Write-Host ""
Write-Host "Files created:"
Get-ChildItem $outputDir | ForEach-Object { Write-Host "  - $($_.Name)" }
