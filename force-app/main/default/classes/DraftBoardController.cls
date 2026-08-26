public with sharing class DraftBoardController {

    @AuraEnabled(cacheable=true)
    public static List<Draft_Season__c> getDraftSeasons() {
        return [
            SELECT Id, Name, Year__c
            FROM Draft_Season__c
            ORDER BY Year__c DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Draft_Pick__c> getDraftPicks(Id seasonId) {
        return [
            SELECT Id, Name, Overall_Pick__c, Round__c, Pick_In_Round__c,
                   Draft_Position__c, Is_Picked__c, Is_Upside_Down__c,
                   League_Member__c, League_Member__r.Name,
                   Player__c, Player__r.FirstName, Player__r.LastName,
                   Player__r.Team__c, Player__r.Bye__c,
                   Player__r.Overall_Rank__c, Player__r.Position_Rank__c,
                   Player__r.Position__c,
                   Traded_To__c, Traded_To__r.Name, Trade_Notes__c,
                   Draft_Season__c
            FROM Draft_Pick__c
            WHERE Draft_Season__c = :seasonId
            ORDER BY Overall_Pick__c ASC
            LIMIT 240
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<League_Member_Season__c> getLeagueMembersBySeason(Id seasonId) {
        return [
            SELECT Id, League_Member__c, League_Member__r.Name, Draft_Order__c, Draft_Season__c
            FROM League_Member_Season__c
            WHERE Draft_Season__c = :seasonId
            ORDER BY Draft_Order__c ASC
            LIMIT 12
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> searchPlayers(String searchTerm, Id seasonId) {
        String searchKey = String.escapeSingleQuotes(searchTerm) + '*';
        List<List<SObject>> results = [
            FIND :searchKey IN NAME FIELDS
            RETURNING Contact(
                Id, FirstName, LastName, Team__c, Bye__c,
                Overall_Rank__c, Position_Rank__c, Position__c, Draft_Season__c
                WHERE (Is_Drafted__c = false OR Is_Drafted__c = null)
                AND Draft_Season__c = :seasonId
                ORDER BY Overall_Rank__c ASC NULLS LAST
                LIMIT 20
            )
        ];
        return (List<Contact>) results[0];
    }

    @AuraEnabled(cacheable=false)
    public static void updateContactDraftedStatus(Id contactId, Boolean isDrafted) {
        if (contactId == null) return;
        Contact c = new Contact(Id = contactId, Is_Drafted__c = isDrafted);
        update c;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDraftBoardConfig() {
        Map<String, Object> config = new Map<String, Object>();

        try {
            List<Draft_Board_Config__mdt> configs = [
                SELECT Enable_Timer__c, Timer_Minutes__c, Timer_Seconds__c,
                       Enable_Sequential_Order__c, Enable_Spell_Checker__c
                FROM Draft_Board_Config__mdt
                LIMIT 1
            ];

            if (!configs.isEmpty()) {
                Draft_Board_Config__mdt cfg = configs[0];
                config.put('enableTimer', cfg.Enable_Timer__c);
                config.put('timerMinutes', cfg.Timer_Minutes__c != null ? cfg.Timer_Minutes__c.intValue() : 0);
                config.put('timerSeconds', cfg.Timer_Seconds__c != null ? cfg.Timer_Seconds__c.intValue() : 0);
                config.put('enableSequentialOrder', cfg.Enable_Sequential_Order__c);
                config.put('enableSpellChecker', cfg.Enable_Spell_Checker__c);
            } else {
                config.put('enableTimer', false);
                config.put('timerMinutes', 0);
                config.put('timerSeconds', 0);
                config.put('enableSequentialOrder', false);
                config.put('enableSpellChecker', false);
            }
        } catch (Exception e) {
            system.debug('Error fetching Draft Board Config: ' + e.getMessage());
            config.put('enableTimer', false);
            config.put('timerMinutes', 0);
            config.put('timerSeconds', 0);
            config.put('enableSequentialOrder', false);
            config.put('enableSpellChecker', false);
        }

        return config;
    }
}
