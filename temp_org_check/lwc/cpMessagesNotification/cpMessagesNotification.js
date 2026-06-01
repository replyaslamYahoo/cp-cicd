import { LightningElement, api, wire } from 'lwc';
import resourcesBasePath from '@salesforce/resourceUrl/CustomerPortal';
import { NavigationMixin } from 'lightning/navigation';

import desktopTemplate from './cpMessagesNotification.html';
import mobileTemplate from './cpMessagesNotificationMobile.html';

//Labels 
import Label_Messages from '@salesforce/label/c.Label_Messages';
import { CurrentPageReference } from 'lightning/navigation';

import { subscribe, unsubscribe, createMessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import MESSAGE_READ_NOTIFICATION_CHANNEL from '@salesforce/messageChannel/CPMessageIsReadNotify__c';

import { getCases } from 'c/cpFeedsModule';

export default class CpMessagesNotification extends NavigationMixin(LightningElement) {
    //Labels
    labels = {
        Label_Messages: Label_Messages
    };

    @api isMobile;
    @api showNotification; // TODO:
    currentUrl;
     
    //Message Channel
     messageContext;
     subscription = null;
     cases = []; 

    icons = {
        notifications: resourcesBasePath + '/icons/support/notifications.png'
    }

      @wire(CurrentPageReference) handlePageReference(pageReference) {
        // do something with pageReference.state
        this.currentUrl = window.location.href;
        //console.log('pageReference', this.currentUrl);
    }

    render() {
        return this.isMobile ? mobileTemplate : desktopTemplate;
    }


    gotoNotificafionCenter(event) {

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/messages-center' // Replace with the URL or relative path of the desired page in your community
            }
        });

    }

    get isCurrentPageNotification() {
        // check if the current page is the notification center
        let appendClass = this.currentUrl.includes('messages') ? 'messages messages-selected' : 'messages';
        if (this.isMobile)
            return appendClass;
        else
            return "container tertiary-button cursor-pointer slds-p-around_x-small" + " " + appendClass;
    }
   
    get isCurrentPageNotificationMessage() {
        // check if the current page is the notification center
        let appendClass = this.currentUrl.includes('messages') ? 'container messages messages-selected' : 'container messages';
        if (this.isMobile)
            return appendClass;
        else
            return "container tertiary-button cursor-pointer slds-p-around_x-small" + " " + appendClass;
    }

    connectedCallback() {
        this.getCasesList();
        // Subscribe to the message channel
        this.messageContext = createMessageContext(this);
        this.subscribeToChannel(); 
    } 

    disconnectedCallback() {
        // Unsubscribe from the message channel
        this.unsubscribeFromChannel();
    }

    subscribeToChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(this.messageContext, MESSAGE_READ_NOTIFICATION_CHANNEL, (message) => { 
                this.checkCommentsAndUpdateNotification(message);
            }, { scope: APPLICATION_SCOPE });
        }
    }

    unsubscribeFromChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    checkCommentsAndUpdateNotification(message){
        let listOfUpdatedcases = [];
        //for each other case, check if unread comment exist , else showNotification=false

        this.showNotification = false;
        this.cases.forEach((currentCase) => {
            if (message.payload.recordId == currentCase.Id){
                currentCase.UnreadCommentExist=false;                
            }
            //check if other case has UnreadComment,
            if (message.payload.recordId!=currentCase.Id && currentCase.UnreadCommentExist==true){
                this.showNotification = true;
            }            
            listOfUpdatedcases.push(currentCase);
        });
        this.cases=listOfUpdatedcases;
    }

   
    async getCasesList(){
        this.loadingFeeds = true;
        return await getCases(null)
            .then(result => {
                this.cases = result;
                this.cases.forEach((currentCase) => {
                    if (currentCase.UnreadCommentExist == true){
                        this.showNotification = true;
                    }
                });
            })
            .catch(error => {
                console.log('getCasesList.error: ' + error);
            })
            .finally(() => {     
                this.loadingFeeds = false;            
            });
    }   

   

}