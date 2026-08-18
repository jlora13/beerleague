/**
 * Import draft board data from CSV exports
 * Usage: Called by import script or manually via Anonymous Apex
 *
 * Expected CSV file format (first row is headers):
 * - draft_seasons.csv: ID,Name,Year__c
 * - league_members.csv: ID,Name,Draft_Order__c
 * - league_member_seasons.csv: ID,League_Member__c,League_Member__r.Name,Draft_Season__c,Draft_Season__r.Name,Draft_Order__c
 * - players.csv: ID,FirstName,LastName,Team__c,Position__c,Overall_Rank__c,Position_Rank__c,Bye__c,Draft_Season__c,Is_Drafted__c
 * - draft_picks.csv: ID,Overall_Pick__c,Round__c,Pick_In_Round__c,League_Member__c,League_Member__r.Name,Player__c,Player__r.FirstName,Player__r.LastName,Is_Picked__c,Is_Upside_Down__c,Traded_To__c,Traded_To__r.Name,Trade_Notes__c,Draft_Season__c
 */
public class DraftBoardImport {

    public static void importDraftSeasons(List<List<String>> csvData) {
        List<Draft_Season__c> seasons = new List<Draft_Season__c>();
        for (Integer i = 1; i < csvData.size(); i++) {
            List<String> row = csvData[i];
            if (row.size() < 3) continue;

            seasons.add(new Draft_Season__c(
                Name = row[1],
                Year__c = Decimal.valueOf(row[2])
            ));
        }
        upsert seasons Name;
        System.debug('Imported ' + seasons.size() + ' Draft Seasons');
    }

    public static void importLeagueMembers(List<List<String>> csvData) {
        List<League_Member__c> members = new List<League_Member__c>();
        for (Integer i = 1; i < csvData.size(); i++) {
            List<String> row = csvData[i];
            if (row.size() < 3) continue;

            members.add(new League_Member__c(
                Name = row[1],
                Draft_Order__c = row[2]
            ));
        }
        upsert members Name;
        System.debug('Imported ' + members.size() + ' League Members');
    }

    public static void importLeagueMemberSeasons(List<List<String>> csvData) {
        Map<String, Id> memberByName = new Map<String, Id>();
        for (League_Member__c m : [SELECT Id, Name FROM League_Member__c]) {
            memberByName.put(m.Name, m.Id);
        }

        Map<String, Id> seasonByName = new Map<String, Id>();
        for (Draft_Season__c s : [SELECT Id, Name FROM Draft_Season__c]) {
            seasonByName.put(s.Name, s.Id);
        }

        List<League_Member_Season__c> lmSeasons = new List<League_Member_Season__c>();
        for (Integer i = 1; i < csvData.size(); i++) {
            List<String> row = csvData[i];
            if (row.size() < 6) continue;

            String memberName = row[2];
            String seasonName = row[4];
            Id memberId = memberByName.get(memberName);
            Id seasonId = seasonByName.get(seasonName);

            if (memberId == null || seasonId == null) {
                System.debug('WARNING: Skipping row - League Member "' + memberName + '" or Season "' + seasonName + '" not found');
                continue;
            }

            lmSeasons.add(new League_Member_Season__c(
                League_Member__c = memberId,
                Draft_Season__c = seasonId,
                Draft_Order__c = Decimal.valueOf(row[5])
            ));
        }
        insert lmSeasons;
        System.debug('Imported ' + lmSeasons.size() + ' League Member Seasons');
    }

    public static void importPlayers(List<List<String>> csvData) {
        Map<String, Id> seasonByName = new Map<String, Id>();
        for (Draft_Season__c s : [SELECT Id, Name FROM Draft_Season__c]) {
            seasonByName.put(s.Name, s.Id);
        }

        List<Contact> players = new List<Contact>();
        for (Integer i = 1; i < csvData.size(); i++) {
            List<String> row = csvData[i];
            if (row.size() < 10) continue;

            String seasonName = row[8];
            Id seasonId = seasonByName.get(seasonName);
            if (seasonId == null) {
                System.debug('WARNING: Skipping player - Season "' + seasonName + '" not found');
                continue;
            }

            Boolean isDrafted = row[9].equalsIgnoreCase('true');

            players.add(new Contact(
                FirstName = row[1],
                LastName = row[2],
                Team__c = row[3],
                Position__c = row[4],
                Overall_Rank__c = row[5].isEmpty() ? null : Decimal.valueOf(row[5]),
                Position_Rank__c = row[6].isEmpty() ? null : Decimal.valueOf(row[6]),
                Bye__c = row[7].isEmpty() ? null : Decimal.valueOf(row[7]),
                Draft_Season__c = seasonId,
                Is_Drafted__c = isDrafted
            ));
        }
        insert players;
        System.debug('Imported ' + players.size() + ' Players');
    }

    public static void importDraftPicks(List<List<String>> csvData) {
        Map<String, Id> memberByName = new Map<String, Id>();
        for (League_Member__c m : [SELECT Id, Name FROM League_Member__c]) {
            memberByName.put(m.Name, m.Id);
        }

        Map<String, Id> seasonByName = new Map<String, Id>();
        for (Draft_Season__c s : [SELECT Id, Name FROM Draft_Season__c]) {
            seasonByName.put(s.Name, s.Id);
        }

        Map<String, Id> playerByKey = new Map<String, Id>();
        for (Contact c : [SELECT Id, FirstName, LastName FROM Contact]) {
            String key = (c.FirstName != null ? c.FirstName : '') + '|' + (c.LastName != null ? c.LastName : '');
            playerByKey.put(key, c.Id);
        }

        List<Draft_Pick__c> picks = new List<Draft_Pick__c>();
        for (Integer i = 1; i < csvData.size(); i++) {
            List<String> row = csvData[i];
            if (row.size() < 15) continue;

            String memberName = row[5];
            String seasonName = row[14];
            String playerFirstName = row[7];
            String playerLastName = row[8];

            Id memberId = memberByName.get(memberName);
            Id seasonId = seasonByName.get(seasonName);
            String playerKey = (playerFirstName != null ? playerFirstName : '') + '|' + (playerLastName != null ? playerLastName : '');
            Id playerId = playerByKey.get(playerKey);

            if (memberId == null || seasonId == null) {
                System.debug('WARNING: Skipping pick - League Member or Season not found');
                continue;
            }

            Boolean isPicked = row[9].equalsIgnoreCase('true');
            Boolean isUpsideDown = row[10].equalsIgnoreCase('true');
            String tradedToName = row[12];
            Id tradedToId = memberByName.get(tradedToName);

            picks.add(new Draft_Pick__c(
                Overall_Pick__c = Decimal.valueOf(row[1]),
                Round__c = Decimal.valueOf(row[2]),
                Pick_In_Round__c = Decimal.valueOf(row[3]),
                League_Member__c = memberId,
                Player__c = playerId,
                Is_Picked__c = isPicked,
                Is_Upside_Down__c = isUpsideDown,
                Traded_To__c = tradedToId,
                Trade_Notes__c = row[13],
                Draft_Season__c = seasonId
            ));
        }
        insert picks;
        System.debug('Imported ' + picks.size() + ' Draft Picks');
    }
}
