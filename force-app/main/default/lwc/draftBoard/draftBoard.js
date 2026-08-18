import { LightningElement, track, wire } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDraftSeasons from '@salesforce/apex/DraftBoardController.getDraftSeasons';
import getDraftPicks from '@salesforce/apex/DraftBoardController.getDraftPicks';
import getLeagueMembersBySeason from '@salesforce/apex/DraftBoardController.getLeagueMembersBySeason';
import searchPlayers from '@salesforce/apex/DraftBoardController.searchPlayers';
import updateContactDraftedStatus from '@salesforce/apex/DraftBoardController.updateContactDraftedStatus';

const TEAMS = 12;
const ROUNDS = 20;
const MAX_ROUNDS = ROUNDS;

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
    @track seasons = [];
    @track selectedSeasonId = 'a02aj00000cBR8fAAG'; // 2026 season
    @track isLoading = true;
    @track searchTerm = '';
    @track playerSearchResults = [];
    @track activePickId = null;
    @track activePrevContactId = null; // contact on the pick before we change it
    @track showPlayerSearch = false;
    @track upsideDown = false;
    @track selectedTradedTo = '';   // League_Member Id chosen in modal
    @track selectedTradeNotes = ''; // Trade_Notes text
    @track error;

    _picksWireResult;
    _memberWireResult;
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

    @wire(getDraftSeasons)
    wiredSeasons({ data, error }) {
        if (data && data.length > 0) {
            this.seasons = data;
        } else if (error) {
            console.error('getDraftSeasons error:', error);
            this.error = error;
        }
    }

    @wire(getLeagueMembersBySeason, { seasonId: '$selectedSeasonId' })
    wiredMembers(result) {
        this._memberWireResult = result;
        if (result.data) {
            this.members = result.data.map(m => ({
                key: m.Draft_Order__c,
                label: m.League_Member__r.Name,
                id: m.League_Member__c
            }));
            this.checkLoadingDone();
        } else if (result.error) {
            console.error('getLeagueMembersBySeason error:', result.error);
            this.error = result.error;
            this.isLoading = false;
        }
    }

    @wire(getDraftPicks, { seasonId: '$selectedSeasonId' })
    wiredPicks(result) {
        this._picksWireResult = result;
        if (result.data) {
            this.picks = result.data.map(p => ({ ...p }));
            this.checkLoadingDone();
        } else if (result.error) {
            console.error('getDraftPicks error:', result.error);
            this.error = result.error;
            this.isLoading = false;
        }
    }

    checkLoadingDone() {
        if (this.members.length > 0 && this.picks.length > 0) {
            this.isLoading = false;
        }
    }

    get seasonOptions() {
        return this.seasons.map(s => ({ label: s.Name, value: s.Id }));
    }

    get columnHeaders() {
        return this.members.map(m => ({
            key: m.key,
            label: m.label
        }));
    }

    get memberOptions() {
        const opts = this.members.map(m => ({ label: m.label, value: m.id }));
        return [{ label: '-- None --', value: '' }, ...opts];
    }

    handleSeasonChange(event) {
        this.selectedSeasonId = event.detail.value;
        this.isLoading = true;
    }

    get grid() {
        const pickByOverall = {};
        this.picks.forEach(p => { pickByOverall[p.Overall_Pick__c] = p; });

        const rows = [];
        for (let round = 1; round <= ROUNDS; round++) {
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
        searchPlayers({ searchTerm: term, seasonId: this.selectedSeasonId })
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
                return Promise.all([
                    refreshApex(this._picksWireResult),
                    refreshApex(this._memberWireResult)
                ]);
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