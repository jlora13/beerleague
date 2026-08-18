/**
 * Run once via Anonymous Apex to seed all 240 Draft_Pick__c records.
 * Usage: Execute in Developer Console or VS Code with "SFDX: Execute Anonymous Apex"
 *
 * Prerequisites:
 *   1. Deploy all metadata first (sf project deploy start)
 *   2. Create your 12 League_Member__c records with Draft_Order__c values 1–12
 *   3. Then run this script
 */
public class DraftBoardSetup {

    private static final Integer TEAMS = 12;
    private static final Integer ROUNDS = 20;

    public static void seedPicks() {
        // Fetch all league members keyed by Draft_Order__c
        Map<Integer, Id> memberByOrder = new Map<Integer, Id>();
        for (League_Member__c m : [SELECT Id, Draft_Order__c FROM League_Member__c WHERE Draft_Order__c != null]) {
            memberByOrder.put((Integer) m.Draft_Order__c, m.Id);
        }

        if (memberByOrder.size() != TEAMS) {
            System.debug('WARNING: Expected ' + TEAMS + ' league members with Draft_Order__c 1–12. Found: ' + memberByOrder.size() + '. Seeding anyway.');
        }

        // Delete any existing picks before re-seeding
        delete [SELECT Id FROM Draft_Pick__c LIMIT 10000];

        List<Draft_Pick__c> picks = new List<Draft_Pick__c>();
        for (Integer overall = 1; overall <= TEAMS * ROUNDS; overall++) {
            Integer pickInRound = Math.mod(overall - 1, TEAMS) + 1;
            Integer round = (Integer) Math.ceil((Double) overall / TEAMS);
            Integer draftPosition = Math.mod(round, 2) == 1 ? pickInRound : TEAMS - pickInRound + 1;

            Draft_Pick__c pick = new Draft_Pick__c(
                Overall_Pick__c = overall,
                League_Member__c = memberByOrder.get(draftPosition)
            );
            picks.add(pick);
        }

        insert picks;
        System.debug('Seeded ' + picks.size() + ' Draft_Pick__c records.');
    }

    public static void seedPicksForSeason(Id seasonId) {
        // Fetch League_Member_Season records for this season, keyed by Draft_Order__c
        Map<Integer, Id> memberByOrder = new Map<Integer, Id>();
        for (League_Member_Season__c lms : [
            SELECT Id, League_Member__c, Draft_Order__c
            FROM League_Member_Season__c
            WHERE Draft_Season__c = :seasonId AND Draft_Order__c != null
        ]) {
            memberByOrder.put((Integer) lms.Draft_Order__c, lms.League_Member__c);
        }

        if (memberByOrder.size() != TEAMS) {
            System.debug('WARNING: Expected ' + TEAMS + ' League_Member_Season records for this season. Found: ' + memberByOrder.size() + '. Seeding anyway.');
        }

        // Check if picks already exist for this season
        Integer existingCount = [SELECT COUNT() FROM Draft_Pick__c WHERE Draft_Season__c = :seasonId];
        if (existingCount > 0) {
            System.debug('WARNING: Season already has ' + existingCount + ' picks. Skipping to avoid duplicates.');
            return;
        }

        List<Draft_Pick__c> picks = new List<Draft_Pick__c>();
        for (Integer overall = 1; overall <= TEAMS * ROUNDS; overall++) {
            Integer pickInRound = Math.mod(overall - 1, TEAMS) + 1;
            Integer round = (Integer) Math.ceil((Double) overall / TEAMS);
            Integer draftPosition = Math.mod(round, 2) == 1 ? pickInRound : TEAMS - pickInRound + 1;

            Draft_Pick__c pick = new Draft_Pick__c(
                Overall_Pick__c = overall,
                League_Member__c = memberByOrder.get(draftPosition),
                Draft_Season__c = seasonId
            );
            picks.add(pick);
        }

        insert picks;
        System.debug('Seeded ' + picks.size() + ' Draft_Pick__c records for season ' + seasonId);
    }
}
