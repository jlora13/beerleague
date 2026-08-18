/**
 * Export all draft board data for backup and future year recreation
 * Usage: Execute in Developer Console or VS Code with "SFDX: Execute Anonymous Apex"
 *
 * Then copy the debug output and save as CSV files
 */
public class DraftBoardExport {

    public static void exportAllData() {
        System.debug('=== DRAFT SEASONS ===');
        exportDraftSeasons();

        System.debug('=== LEAGUE MEMBERS ===');
        exportLeagueMembers();

        System.debug('=== LEAGUE MEMBER SEASONS ===');
        exportLeagueMemberSeasons();

        System.debug('=== PLAYERS (CONTACTS) ===');
        exportPlayers();

        System.debug('=== DRAFT PICKS ===');
        exportDraftPicks();
    }

    private static void exportDraftSeasons() {
        System.debug('ID,Name,Year__c');
        for (Draft_Season__c season : [SELECT Id, Name, Year__c FROM Draft_Season__c ORDER BY Year__c DESC]) {
            System.debug(season.Id + ',' + season.Name + ',' + season.Year__c);
        }
    }

    private static void exportLeagueMembers() {
        System.debug('ID,Name,Draft_Order__c');
        for (League_Member__c member : [SELECT Id, Name, Draft_Order__c FROM League_Member__c ORDER BY Draft_Order__c ASC]) {
            System.debug(member.Id + ',' + member.Name + ',' + member.Draft_Order__c);
        }
    }

    private static void exportLeagueMemberSeasons() {
        System.debug('ID,League_Member__c,League_Member__r.Name,Draft_Season__c,Draft_Season__r.Name,Draft_Order__c');
        for (League_Member_Season__c lms : [
            SELECT Id, League_Member__c, League_Member__r.Name, Draft_Season__c, Draft_Season__r.Name, Draft_Order__c
            FROM League_Member_Season__c
            ORDER BY Draft_Season__r.Year__c DESC, Draft_Order__c ASC
        ]) {
            System.debug(lms.Id + ',' + lms.League_Member__c + ',' + lms.League_Member__r.Name + ',' +
                        lms.Draft_Season__c + ',' + lms.Draft_Season__r.Name + ',' + lms.Draft_Order__c);
        }
    }

    private static void exportPlayers() {
        System.debug('ID,FirstName,LastName,Team__c,Position__c,Overall_Rank__c,Position_Rank__c,Bye__c,Draft_Season__c,Is_Drafted__c');
        for (Contact player : [
            SELECT Id, FirstName, LastName, Team__c, Position__c, Overall_Rank__c, Position_Rank__c, Bye__c, Draft_Season__c, Is_Drafted__c
            FROM Contact
            WHERE Draft_Season__c != null
            ORDER BY Draft_Season__c, Overall_Rank__c
        ]) {
            String drafted = player.Is_Drafted__c ? 'true' : 'false';
            System.debug(player.Id + ',' + player.FirstName + ',' + player.LastName + ',' + player.Team__c + ',' +
                        player.Position__c + ',' + player.Overall_Rank__c + ',' + player.Position_Rank__c + ',' +
                        player.Bye__c + ',' + player.Draft_Season__c + ',' + drafted);
        }
    }

    private static void exportDraftPicks() {
        System.debug('ID,Overall_Pick__c,Round__c,Pick_In_Round__c,League_Member__c,League_Member__r.Name,Player__c,Player__r.FirstName,Player__r.LastName,Is_Picked__c,Is_Upside_Down__c,Traded_To__c,Traded_To__r.Name,Trade_Notes__c,Draft_Season__c');
        for (Draft_Pick__c pick : [
            SELECT Id, Overall_Pick__c, Round__c, Pick_In_Round__c, League_Member__c, League_Member__r.Name,
                   Player__c, Player__r.FirstName, Player__r.LastName, Is_Picked__c, Is_Upside_Down__c,
                   Traded_To__c, Traded_To__r.Name, Trade_Notes__c, Draft_Season__c
            FROM Draft_Pick__c
            ORDER BY Draft_Season__c, Overall_Pick__c
        ]) {
            String isPicked = pick.Is_Picked__c ? 'true' : 'false';
            String isUpsideDown = pick.Is_Upside_Down__c ? 'true' : 'false';
            String tradeNotes = pick.Trade_Notes__c != null ? '"' + pick.Trade_Notes__c.replaceAll('"', '""') + '"' : '';

            System.debug(pick.Id + ',' + pick.Overall_Pick__c + ',' + pick.Round__c + ',' + pick.Pick_In_Round__c + ',' +
                        pick.League_Member__c + ',' + (pick.League_Member__r != null ? pick.League_Member__r.Name : '') + ',' +
                        (pick.Player__c != null ? pick.Player__c : '') + ',' +
                        (pick.Player__r != null ? pick.Player__r.FirstName : '') + ',' +
                        (pick.Player__r != null ? pick.Player__r.LastName : '') + ',' +
                        isPicked + ',' + isUpsideDown + ',' +
                        (pick.Traded_To__c != null ? pick.Traded_To__c : '') + ',' +
                        (pick.Traded_To__r != null ? pick.Traded_To__r.Name : '') + ',' + tradeNotes + ',' + pick.Draft_Season__c);
        }
    }
}
