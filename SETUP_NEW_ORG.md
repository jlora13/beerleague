# Beer League Draft Board - New Org Setup

Complete guide for deploying Beer League Draft Board to a new Salesforce organization.

## Quick Start (Automated)

The easiest way to set up a new org is to use the automated setup script:

```powershell
# Full setup (deploy + config + create base data + seed picks)
.\setup-new-org.ps1 -TargetOrg "my-new-org"

# Or run specific steps
.\setup-new-org.ps1 -TargetOrg "my-new-org" -Action "deploy"      # Only deploy metadata
.\setup-new-org.ps1 -TargetOrg "my-new-org" -Action "config"      # Config guidance
.\setup-new-org.ps1 -TargetOrg "my-new-org" -Action "data"        # Create base data
.\setup-new-org.ps1 -TargetOrg "my-new-org" -Action "seed"        # Seed draft picks
```

## Setup Steps (Manual)

### 1. Authenticate with Target Org

```bash
sf org login web --alias my-org-alias
```

### 2. Deploy Metadata

Deploy all code, objects, custom fields, and components:

```bash
sf project deploy start --target-org my-org-alias
```

This deploys:
- **Custom Objects**: Draft_Pick__c, Draft_Season__c, League_Member__c, League_Member_Season__c
- **Custom Metadata Type**: Draft_Board_Config__mdt
- **Apex Classes**: DraftBoardController, DraftBoardSetup, DraftBoardExport, DraftBoardImport
- **Lightning Components**: draftBoard (main draft board LWC)
- **Other**: Page layouts, record types, applications, flex pages

### 3. Create Draft Board Configuration

The Draft_Board_Config__mdt custom metadata controls all feature toggles:

**In Salesforce UI:**
1. Setup → Custom Metadata Types
2. Click "Draft Board Config"
3. Click "Manage Records" → "New"
4. Fill in:
   ```
   Label: Default Config
   API Name: Default_Config
   Enable_Timer__c: ☑ (checked)
   Timer_Minutes__c: 5
   Timer_Seconds__c: 0
   Enable_Spell_Checker__c: ☑ (checked)
   Enable_Sequential_Order__c: ☐ (unchecked)
   ```
5. Save

**Configuration Options:**
- `Enable_Timer__c` - Activates countdown timer on the board
- `Timer_Minutes__c` - Timer duration (minutes)
- `Timer_Seconds__c` - Timer duration (seconds)
- `Enable_Spell_Checker__c` - Enforce exact player name matching in search
- `Enable_Sequential_Order__c` - Require picks in sequential order (future feature)

### 4. Create Base Data

Create League Members (teams), Draft Seasons, and link them.

**Via Anonymous Apex in Developer Console or VS Code:**

```apex
// Create League Members (12 teams)
List<League_Member__c> members = new List<League_Member__c>();
String[] teamNames = new String[]{
    'Frankie', 'Max', 'Jake', 'Jesse', 'Connor', 'Justin',
    'Nick', 'Scott', 'Jared', 'Jack', 'Mike', 'Chris'
};
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

// Create League Member Season records (link members to season)
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
```

### 5. Seed Draft Picks

Generate all 240 draft pick records (12 teams × 20 rounds):

**Via Anonymous Apex:**
```apex
Id seasonId = [SELECT Id FROM Draft_Season__c ORDER BY Year__c DESC LIMIT 1].Id;
DraftBoardSetup.seedPicksForSeason(seasonId);
```

Or via script:
```bash
sf apex run --file scripts/apex/seedPicks.apex --target-org my-org-alias
```

Output:
```
Seeded 240 Draft_Pick__c records for season [seasonId]
```

### 6. Load Player Data (Optional)

If importing player data from an existing org, export and import Contact records with these fields:
- FirstName, LastName
- Team__c
- Position__c (QB, RB, WR, TE, K, DST)
- Overall_Rank__c
- Position_Rank__c
- Bye__c
- Draft_Season__c
- Is_Drafted__c

Use the export/import script:

```powershell
# Export from existing org
.\export-draft-data.ps1 -Export -OrgAlias existing-org -OutputDir ".\data-backup"

# Import to new org (requires manual data loader or third-party tool)
# CSV files will be in .\data-backup/ ready for import
```

### 7. Access the Draft Board

1. Log into your Salesforce org
2. Navigate to the **"Beer League Draft"** app
3. Select a season from the dropdown
4. Start drafting!

---

## Data Backup & Migration

### Export All Data

Export all draft board data to CSV files:

```powershell
.\export-draft-data.ps1 -Export -OutputDir ".\backup-2026"
```

This creates CSV files for:
- draft_seasons.csv
- league_members.csv
- league_member_seasons.csv
- players.csv (Contacts)
- draft_picks.csv

### Import Data to Another Org

```powershell
# Export from source org
.\export-draft-data.ps1 -Export -OrgAlias prod-org -OutputDir ".\data-export"

# Then import to target org (using Data Loader or similar)
```

**Import Order** (important):
1. draft_seasons.csv
2. league_members.csv
3. league_member_seasons.csv
4. players.csv (Contacts)
5. draft_picks.csv

---

## Object Reference

### Draft_Season__c
A draft season (e.g., "2026 Season").

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Name | Text | ✓ | Season name (e.g., "2026 Season") |
| Year__c | Number | | Year of the season |

### League_Member__c
A league member / team owner.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Name | Text | ✓ | Member name (e.g., "Frankie") |
| Draft_Order__c | Number | | Default draft position (1-12) |

### League_Member_Season__c
Links a League Member to a Season with custom Draft Order for that season.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| League_Member__c | Lookup | ✓ | Reference to League_Member__c |
| Draft_Season__c | Lookup | ✓ | Reference to Draft_Season__c |
| Draft_Order__c | Number | | Draft position for this season (1-12) |

### Draft_Pick__c
One draft slot. There are 240 per season (12 teams × 20 rounds).

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Overall_Pick__c | Number | ✓ | Pick number (1-240) |
| Round__c | Number | ✓ | Round number (1-20) |
| Pick_In_Round__c | Number | ✓ | Position in round (1-12) |
| League_Member__c | Lookup | ✓ | Team making this pick |
| Player__c | Lookup | | Contact record (if filled) |
| Is_Picked__c | Checkbox | | Whether slot is filled |
| Is_Upside_Down__c | Checkbox | | UI flag (displays upside down) |
| Traded_To__c | Lookup | | League Member if traded |
| Trade_Notes__c | Text | | Trade details/notes |
| Draft_Season__c | Lookup | ✓ | Which season |

### Contact (Player)
NFL player available for drafting.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| FirstName | Text | | Player first name |
| LastName | Text | | Player last name |
| Team__c | Text | | NFL team (e.g., "KC", "SF") |
| Position__c | Picklist | | QB, RB, WR, TE, K, DST |
| Overall_Rank__c | Number | | ADP or overall rank |
| Position_Rank__c | Number | | Rank within position |
| Bye__c | Number | | Team bye week |
| Draft_Season__c | Lookup | | Which season available for |
| Is_Drafted__c | Checkbox | | Whether drafted this season |

---

## Apex Classes

### DraftBoardController
Main backend logic for the draft board.

**Key Methods:**
- `getDraftSeasons()` - Get all available seasons
- `getDraftPicks(seasonId)` - Get picks for a season
- `getLeagueMembersBySeason(seasonId)` - Get teams for a season
- `searchPlayers(searchTerm, seasonId)` - Search for available players
- `updateContactDraftedStatus(contactId, isDrafted)` - Mark player as drafted
- `getDraftBoardConfig()` - Get feature configuration

### DraftBoardSetup
Seeds draft pick records.

**Key Methods:**
- `seedPicks()` - Seed picks for the default season
- `seedPicksForSeason(seasonId)` - Seed picks for a specific season

Generates 240 picks with correct round/snake draft ordering.

### DraftBoardExport
Exports all data to CSV format (via debug output).

**Usage:**
```apex
DraftBoardExport.exportAllData();  // Export everything
DraftBoardExport.exportDraftSeasons();  // Export just seasons
// etc.
```

Copy the debug output to CSV files.

### DraftBoardImport
Imports data from CSV format.

**Key Methods:**
- `importDraftSeasons(csvData)`
- `importLeagueMembers(csvData)`
- `importLeagueMemberSeasons(csvData)`
- `importPlayers(csvData)`
- `importDraftPicks(csvData)`

---

## Features

### 🕐 Timer
A countdown timer running continuously on the board. Resets only when a player is selected (not when opening modal or changing tabs). Settings:
- Pause/Resume button (⏸/▶)
- Manual reset button (↻)
- Displays MM:SS format
- Red banner when expired (TIME'S UP, DRINK YOU STUPID IDIOT!)
- Persists across tab switches via sessionStorage

**Configure in Draft_Board_Config__mdt:**
- Enable_Timer__c: true/false
- Timer_Minutes__c: Duration in minutes
- Timer_Seconds__c: Duration in seconds

### ✓ Spell Checker
When enabled, enforces exact player name matching (case-insensitive).

**Flow:**
1. User types in search box → No results shown
2. User checks "Spell Checker" checkbox → Exact match search runs
3. If match found → Player displays
4. If no match → Red banner shows "WRONG, DRINK YOU STUPID IDIOT!"

**Configure in Draft_Board_Config__mdt:**
- Enable_Spell_Checker__c: true/false

### 📊 Traded Picks
Show which league member a pick was traded to:
- "TRADED TO: [Member Name]" badge displays prominently
- Lookup field on Draft_Pick__c: Traded_To__c
- Trade notes field for details

### 📌 Upside Down
Display players in the cell rotated 180° (UI flag for special picks).
- Is_Upside_Down__c checkbox on Draft_Pick__c
- Toggle via modal: "🙃 Add player upside down"

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No League Members" in dropdown | Create League_Member__c records with Draft_Order__c 1-12 |
| Draft picks not seeding | Ensure League_Member_Season__c records exist for the season |
| Timer not showing | Check Draft_Board_Config__mdt has Enable_Timer__c = true |
| Player search returns no results | Ensure Contact records have Draft_Season__c populated |
| "Spell Checker" checkbox missing | Check Draft_Board_Config__mdt has Enable_Spell_Checker__c = true |

---

## File Structure

```
force-app/main/default/
├── classes/
│   ├── DraftBoardController.cls
│   ├── DraftBoardController.cls-meta.xml
│   ├── DraftBoardSetup.cls
│   ├── DraftBoardSetup.cls-meta.xml
│   ├── DraftBoardExport.cls
│   ├── DraftBoardExport.cls-meta.xml
│   ├── DraftBoardImport.cls
│   └── DraftBoardImport.cls-meta.xml
├── lwc/
│   └── draftBoard/
│       ├── draftBoard.js
│       ├── draftBoard.html
│       ├── draftBoard.css
│       └── draftBoard.js-meta.xml
├── objects/
│   ├── Draft_Pick__c/
│   ├── Draft_Season__c/
│   ├── League_Member__c/
│   └── League_Member_Season__c/
├── customMetadata/
│   └── Draft_Board_Config__mdt/
├── applications/
│   └── Beer_League_Draft.app-meta.xml
└── flexipages/
    ├── Draft_Pick_Record_Page.flexipage-meta.xml
    └── League_Member_Record_Page.flexipage-meta.xml

scripts/
├── apex/
│   └── seedPicks.apex
└── setup/
    └── (future setup scripts)

Root files:
├── setup-new-org.ps1              # Automated setup script
├── export-draft-data.ps1          # Export/import data script
└── SETUP_NEW_ORG.md               # This file
```

---

## Support

For questions or issues:
1. Check the Troubleshooting section above
2. Review Apex class comments in force-app/main/default/classes/
3. Examine the DraftBoardController for available methods
4. Check Draft_Board_Config__mdt for feature toggles
