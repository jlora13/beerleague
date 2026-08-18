import { LightningElement, track, wire } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDraftPicks from '@salesforce/apex/DraftBoardController.getDraftPicks';
import getLeagueMembers from '@salesforce/apex/DraftBoardController.getLeagueMembers';
import searchPlayers from '@salesforce/apex/DraftBoardController.searchPlayers';
import updateContactDraftedStatus from '@salesforce/apex/DraftBoardController.updateContactDraftedStatus';

const TEAMS = 12;
const ROUNDS = 20;

// Maps Position__c picklist value → CSS class suffix
const POSITION_CLASS = {
    'WR':  'pos-wr',
    'RB':  'pos-rb',
    'QB':  'pos-qb',
    'K':   'pos-k',
    'DST': 'pos-dst',
    'TE':  'pos-te'
};

export default class DraftBoard extends LightningElement {
    @track picks = [];
    @track members = [];
    @track isLoading = true;
    @track searchTerm = '';
    @track playerSearchResults = [];
    @track activePickId = null;
    @track activePrevContactId = null; // contact on the pick before we change it
    @track showPlayerSearch = false;
    @track upsideDown = false;
    @track selectedTradedTo = '';   // League_Member Id chosen in modal
    @track selectedTradeNotes = ''; // Trade_Notes text
    @track maxRounds = 20;
    @track error;

    _picksWireResult;
    _searchTimer;

    // Odd rounds: left-to-right; even rounds: right-to-left
    overallPickFor(team, round) {
        return round % 2 === 1
            ? (round - 1) * TEAMS + team
            : (round - 1) * TEAMS + (TEAMS + 1 - team);
    }

    positionClass(position) {
        return POSITION_CLASS[position] || 'pos-default';
    }

    @wire(getLeagueMembers)
    wiredMembers({ data, error }) {
        if (data) {
            this.members = data;
            this.checkLoadingDone();
        } else if (error) {
            this.error = error;
            this.isLoading = false;
        }
    }

    @wire(getDraftPicks)
    wiredPicks(result) {
        this._picksWireResult = result;
        if (result.data) {
            this.picks = result.data.map(p => ({ ...p }));
            this.checkLoadingDone();
        } else if (result.error) {
            this.error = result.error;
            this.isLoading = false;
        }
    }

    checkLoadingDone() {
        if (this.members.length > 0 && this.picks.length > 0) {
            this.isLoading = false;
        }
    }

    get columnHeaders() {
        return this.members.map(m => ({
            key: m.Draft_Order__c,
            label: m.Name
        }));
    }

    get memberOptions() {
        const opts = this.members.map(m => ({ label: m.Name, value: m.Id }));
        return [{ label: '-- None --', value: '' }, ...opts];
    }

    get grid() {
        const pickByOverall = {};
        this.picks.forEach(p => { pickByOverall[p.Overall_Pick__c] = p; });

        const rows = [];
        for (let round = 1; round <= this.maxRounds; round++) {
            const cells = [];
            for (let teamIdx = 0; teamIdx < this.members.length; teamIdx++) {
                const team = teamIdx + 1;
                const overall = this.overallPickFor(team, round);
                const pick = pickByOverall[overall] || {};
                const player = pick.Player__r || null;
                const isPicked = !!pick.Is_Picked__c;
                const position = player ? (player.Position__c || '') : '';
                const posClass = isPicked ? this.positionClass(position) : '';
                const isActive = this.activePickId === pick.Id;

                cells.push({
                    key: overall,
                    overall,
                    pickId: pick.Id || null,
                    isPicked,
                    playerFirstName:   player ? (player.FirstName || '') : '',
                    playerLastName:    player ? (player.LastName || '') : '',
                    playerTeam:        player ? (player.Team__c || '') : '',
                    playerBye:         player ? (player.Bye__c != null ? player.Bye__c : '') : '',
                    playerOverallRank: player ? (player.Overall_Rank__c != null ? player.Overall_Rank__c : '') : '',
                    playerPositionRank:player ? (player.Position_Rank__c != null ? player.Position_Rank__c : '') : '',
                    playerPosition:    position,
                    isUpsideDown:      !!pick.Is_Upside_Down__c,
                    tradedTo:          pick.Traded_To__c || null,
                    tradedToName:      pick.Traded_To__r ? pick.Traded_To__r.Name : '',
                    cellClass: 'draft-cell' + (isPicked ? (' picked ' + posClass) : '') + (isActive ? ' active' : ''),
                    contentClass: 'cell-content' + (pick.Is_Upside_Down__c ? ' upside-down' : '')
                });
            }
            rows.push({ key: round, round, cells });
        }
        return rows;
    }

    handleCellClick(event) {
        const pickId = event.currentTarget.dataset.pickid;
        if (!pickId) return;

        const pick = this.picks.find(p => p.Id === pickId);
        this.activePrevContactId = (pick && pick.Player__c) ? pick.Player__c : null;
        this.selectedTradedTo = (pick && pick.Traded_To__c) ? pick.Traded_To__c : '';
        this.selectedTradeNotes = (pick && pick.Trade_Notes__c) ? pick.Trade_Notes__c : '';

        this.activePickId = pickId;
        this.showPlayerSearch = true;
        this.searchTerm = '';
        this.playerSearchResults = [];

        setTimeout(() => {
            const input = this.refs.playerSearchInput;
            if (input) {
                input.focus();
            }
        }, 0);
    }

    handleTradedToChange(event) {
        this.selectedTradedTo = event.detail.value;
    }

    handleTradeNotesChange(event) {
        this.selectedTradeNotes = event.target.value;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchTimer);
        if (this.searchTerm.length >= 2) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._searchTimer = setTimeout(() => {
                this.doSearch(this.searchTerm);
            }, 300);
        } else {
            this.playerSearchResults = [];
        }
    }

    doSearch(term) {
        searchPlayers({ searchTerm: term })
            .then(results => {
                this.playerSearchResults = results.map(c => ({
                    id: c.Id,
                    firstName: c.FirstName || '',
                    lastName: c.LastName || '',
                    team: c.Team__c || '',
                    bye: c.Bye__c != null ? c.Bye__c : '',
                    overallRank: c.Overall_Rank__c != null ? c.Overall_Rank__c : '',
                    positionRank: c.Position_Rank__c != null ? c.Position_Rank__c : '',
                    position: c.Position__c || ''
                }));
            })
            .catch(err => {
                console.error('Player search error', err);
            });
    }

    handleUpsideDownToggle(event) {
        this.upsideDown = event.target.checked;
    }

    handlePlayerSelect(event) {
        const contactId = event.currentTarget.dataset.contactid;
        this.savePick(this.activePickId, contactId, this.activePrevContactId, this.upsideDown, this.selectedTradedTo, this.selectedTradeNotes);
        this.showPlayerSearch = false;
        this.playerSearchResults = [];
        this.upsideDown = false;
        this.selectedTradedTo = '';
        this.selectedTradeNotes = '';
    }

    handleClearPick() {
        this.savePick(this.activePickId, null, this.activePrevContactId, false, this.selectedTradedTo, this.selectedTradeNotes);
        this.showPlayerSearch = false;
        this.upsideDown = false;
        this.selectedTradedTo = '';
        this.selectedTradeNotes = '';
    }

    handleSaveTradeInfo() {
        const pick = this.picks.find(p => p.Id === this.activePickId);
        const currentPlayer = pick ? pick.Player__c : null;
        this.savePick(this.activePickId, currentPlayer, this.activePrevContactId, false, this.selectedTradedTo, this.selectedTradeNotes);
        this.showPlayerSearch = false;
        this.upsideDown = false;
        this.selectedTradedTo = '';
        this.selectedTradeNotes = '';
    }

    handleCloseSearch() {
        this.showPlayerSearch = false;
        this.activePickId = null;
        this.activePrevContactId = null;
        this.playerSearchResults = [];
        this.upsideDown = false;
        this.selectedTradedTo = '';
        this.selectedTradeNotes = '';
    }

    handleMaxRoundsChange(event) {
        this.maxRounds = parseInt(event.detail.value, 10);
    }

    savePick(pickId, newContactId, prevContactId, upsideDown, tradedTo, tradeNotes) {
        const fields = {
            Id: pickId,
            Player__c: newContactId,
            Is_Picked__c: !!newContactId,
            Is_Upside_Down__c: !!upsideDown,
            Traded_To__c: tradedTo || null,
            Trade_Notes__c: tradeNotes || null
        };

        updateRecord({ fields })
            .then(() => {
                // Unmark the previous player if they're being swapped out or cleared
                const unmarkPromise = prevContactId && prevContactId !== newContactId
                    ? updateContactDraftedStatus({ contactId: prevContactId, isDrafted: false })
                    : Promise.resolve();

                // Mark the new player as drafted
                const markPromise = newContactId
                    ? updateContactDraftedStatus({ contactId: newContactId, isDrafted: true })
                    : Promise.resolve();

                return Promise.all([unmarkPromise, markPromise]);
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: newContactId ? 'Pick saved' : 'Pick cleared',
                    message: newContactId ? 'Player drafted successfully.' : 'Pick slot cleared.',
                    variant: newContactId ? 'success' : 'info'
                }));
                return refreshApex(this._picksWireResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error saving pick',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
            });
    }

    get hasError() { return !!this.error; }
    get errorMessage() { return this.error ? JSON.stringify(this.error) : ''; }
    get noPicksReady() { return !this.isLoading && this.picks.length === 0; }
}