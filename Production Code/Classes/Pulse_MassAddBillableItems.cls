/*
 *  VF Page:        Pulse_MassAddBillableItems
 *  Controller:     Pulse_MassAddBillableItems
 *  Test Class:     Pulse_MassAddBillableItems_Test
 *  Description:    VF Page for Button to mass add Billable Items to a Work Request.
 *                  Picks up any Pricing Item associated to a Pricing Library on the WR's 
 *                  Project and not already associated to a Billable Item on the WR. If 
 *                  the Pricing Item is one of the defaults for the current Work Request record type
 *                  that is shown on the table.
 *
 *
 *      Date:       Developer:          Detail:
 *  --------------------------------------------------------------------------------
 *      03/22/19    JDaru               Newly Created
*/
public class Pulse_MassAddBillableItems {
    public list<selectablePricingItems> selectablePItems {get; set;}
    public map<string, Id> pricingItemToLibraryMap {get; set;}
    public list<EDiscovery_BillableItems__c> currentBillableItems {get; set;}
    public list<EDiscovery_PricingItems__c> originalPIList {get; set;}
    public list<selectablePricingItems> userChosenPItems {get; set;}
    public map<string, boolean> selectionMap {get; set;}
    public Boolean newRecordSection {get; set;}
    public Boolean newRecordError {get; set;}
    public string recordError {get; set;}
    public Id wrId {get; set;}
    public list<SelectablePricingItems> pageItems {get; set;}
    public String pageSize {get; set;}
    public String pageNumber {get; set;}
    public String lastPage {get; set;}
    public boolean disablePrevious {get; set;}
    public boolean disableNext {get; set;}
    public list<SelectOption> materialCodeFilter {get; set;}
    public list<SelectOption> pageSizeList {get; set;}
    public string materialCode {get; set;}
    public string wrName {get; set;}
    public string wrRecordType {get; set;}
    public Id projId {get; set;}
    public string projName {get; set;}
    public string returnURL {get; set;}
    public string wrIdKey {get; set;}
    public string wrNameKey {get; set;}
    public string projIdKey {get; set;}
    public string projNameKey {get; set;}
    public string sortDirection {get; set;}
    public string sortExpression {get; set;}
    public string prevsortExpression {get; set;}
    public map<string, string> pageParams {get; set;}

    // page constructor populates field keys and defaults. Also runs initial query
    // against Pricing Items required for the page. Those query results are the basis
    // for any additional queries the page requires against Pricing Item
    public Pulse_MassAddBillableItems(ApexPages.StandardController myController){
        newRecordSection = false;
        pageParams = ApexPages.currentPage().getParameters();
        wrIdKey = 'CF00N3100000GErwK_lkid';
        wrNameKey = 'CF00N3100000GErwK';
        projIdKey = 'CF00N3100000GErwE_lkid';
        projNameKey = 'CF00N3100000GErwE';
       	// populate default values and page parameter values
       	populateIdentityParameters(wrIdKey, wrNameKey, projIdKey, projNameKey); 
        // if(pageParams.keySet().contains('MassAddBi')){
        	// initial query for Pricing Items that could be added as Billable Items
        	getPricingItems();
        // }
    }
    
    // populate identity parameters (WR Name, Record type etc...) also set some page defaults
    public void populateIdentityParameters(string wrIdKey, string wrNameKey, string projIdKey, string projNameKey){
        if(pageParams.get(wrIdKey) != null){
        	// given the work request Id populate the other 4
            wrId = pageParams.get(wrIdKey);
            EDiscovery_WorkRequest__c wrRecord = [select Id, Name, Project__c, Project__r.Name, RecordType.Name from EDiscovery_WorkRequest__c where Id = : wrId];
			wrName = wrRecord.Name;
            wrRecordType = wrRecord.RecordType.Name;
            projId = wrRecord.Project__c;
            projName = wrRecord.Project__r.Name;
        }
        currentBillableItems = new list<EDiscovery_BillableItems__c>();
        sortDirection = 'ASC';
        sortExpression = 'MaterialCode';
        prevsortExpression = 'MaterialCode';
        materialCodeFilter = new list<SelectOption>();
        materialCodeFilter.add(new SelectOption('-- None --', '-- None --'));
        materialCode = '-- None --';
        pageSizeList = new list<SelectOption>{
        									new SelectOption('15', '15'),
                                    		new SelectOption('25', '25'),
                                    		new SelectOption('50', '50'),
                                    		new SelectOption('100', '100'),
                                    		new SelectOption('200', '200')};
        selectionMap = new map<string, Boolean>();
        pageSize = '25';
    	pageNumber = '1';
        pageItems = new list<SelectablePricingItems>();
        disablePrevious = true;
    }
    
    // initial query for Pricing items needed
    public void getPricingItems() {
        // build a map of Pricing Item name to Pricing Library id used in part to restrict Pricing Item query 
        // and also to populate the Pricing Library lookup later on new Billable Items
        pricingItemToLibraryMap = buildItemToLibraryMap();
        // query for all existing billable items on the current WR the Pricing Items that exist in this list will be removed from
        // what is shown to the user for selection.
        currentBillableItems = [select Id, PricingLibrary__c, PricingItem__c, Pricing_Item_ID__c 
                                                                    from EDiscovery_BillableItems__c where WorkRequest__c = : wrId];
        // create a set of Pricing Item names for the query using the keyset from the map and removing all of the names in the Billable Item query.
        set<string> pricingItemsNotBilled = getUnbilledPricingItems(pricingItemToLibraryMap.keySet(), Pulse_Utils.getFieldValueSet(currentBillableItems, 'Pricing_Item_ID__c'));
        originalPIList = [Select Id, Name, BillableItem__c, Unit__c, Material_Code__c, WR_Billable_Types__c
                                                    FROM EDiscovery_PricingItems__c 
                                                    WHERE Name in : pricingItemsNotBilled order by Material_Code__c ASC Nulls Last];
        // get the material code values from all Pricing items and add each as a SelectOption after sorting
        set<string> materialCodes = Pulse_Utils.getFieldValueSet(originalPIList, 'Material_Code__c');
        list<string> materialCodeList = new list<string>(materialCodes);
        materialCodeList.sort();
        for(string matCode : materialCodeList) materialCodeFilter.add(new SelectOption(matCode, matCode));
        disableNext = (originalPIList.size() <= Integer.valueOf(pageSize));
        selectablePItems = new list<selectablePricingItems>();
        boolean defaultBillable = false;
    	// query for Pricing Items the user can add Billable Items for, identify whether the Billable Item would be created by default
        // for a new  Work Request record.
        for(EDiscovery_PricingItems__c eachPI : originalPIList){
            If(eachPI.WR_Billable_Types__c != null) {
                defaultBillable = eachPI.WR_Billable_Types__c.contains(wrRecordType);
            } else {
                defaultBillable = false;
            }
            SelectablePricingItems newItem = new SelectablePricingItems(eachPI, defaultBillable, false);
         	selectablePItems.add(newItem);
            if(pageItems.size() < Integer.valueOf(pageSize)) pageItems.add(newItem);
            selectionMap.put(eachPI.Name, false);
        }
        system.debug(selectablePItems.size());
		getLastPage();
    }
    
    // calculate based on page size and total records available what the last page will be
    public void getLastPage() {
        Integer recordTotal = selectablePItems.size();
        system.debug(recordTotal);
		Integer pageSizeInt = Integer.valueOf(pageSize);
        system.debug(pageSizeInt);
		Integer lastPageInt = (recordTotal/pageSizeInt < 1 ? 1 : recordTotal/pageSizeInt);
		system.debug(lastPageInt);
        system.debug(math.mod(lastPageInt, recordTotal));
        if(math.mod(lastPageInt, recordTotal) != 0) lastPageInt += 1;
        system.debug(lastPageInt);
        lastPage = String.valueOf(lastPageInt);
        system.debug('last page is now: ' + lastPage);
    }
    
    // method kicked off by requesting to sort the selection table by a specific field. Has to loop through 
    // the existing records and map the 'selected' values so selections can be retained. Then requeries and rebuilds the 
    // the table with the appropriate Order By field and direction. Will also take into account any Material code selected 
    // to filter by.
    public void updateTable(){
        if(prevsortExpression != sortExpression && prevsortExpression != null) sortDirection = 'DESC';
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        string queryString = 'Select Id, Name, BillableItem__c, Unit__c, Material_Code__c, WR_Billable_Types__c ' +
            					'FROM EDiscovery_PricingItems__c WHERE Id in : originalPIList';
        if(materialCode != '-- None --') queryString += ' AND Material_Code__c = \'' + materialCode + '\'';
        switch on sortDirection{ // The switch on sortDirection checks the variables previous value, sets it, and rebuilds the query
            when 'None' { 
            	sortDirection = 'ASC';
                switch on sortExpression{
                    when 'PricingItemID' { queryString += ' ORDER BY Name ASC NULLS LAST';}
                    when 'DefaultItem','Selected' {sortListByAttribute(queryString);}
                    when 'MaterialCode' {queryString += ' ORDER BY Material_Code__c ASC NULLS LAST';}
                    when 'BillableItem' {queryString += ' ORDER BY BillableItem__c ASC NULLS LAST';}
                    when 'Unit' {queryString += ' ORDER BY Unit__c ASC NULLS LAST';}
                }
            }
            when 'ASC' { 
               	sortDirection = 'DESC';
                switch on sortExpression{
                    when 'PricingItemID' { queryString += ' ORDER BY Name DESC NULLS FIRST';}
                    when 'DefaultItem','Selected' {sortListByAttribute(queryString);}
                    when 'MaterialCode' {queryString += ' ORDER BY Material_Code__c DESC NULLS FIRST';}
                    when 'BillableItem' {queryString += ' ORDER BY BillableItem__c DESC NULLS FIRST';}
                    when 'Unit' {queryString += ' ORDER BY Unit__c DESC NULLS FIRST';}
                }
            }  /*
            when 'DESC' { 
               	sortDirection = 'None';
				sortExpression = '';
            } */
        }
        if(sortExpression != 'DefaultItem' && sortExpression != 'Selected'){
            list<selectablePricingItems> newOrderedList = new list<selectablePricingItems>();
            list<EDiscovery_PricingItems__c> orderedPI = Database.query(queryString);
            // use the query results to build an ordered list of selectable records
            for(EDiscovery_PricingItems__c eachPI : orderedPI) { 
                Boolean defaultBillable = false;
                If(eachPI.WR_Billable_Types__c != null) {
                    defaultBillable = eachPI.WR_Billable_Types__c.contains(wrRecordType);
                }            
                Boolean isSelected = selectionMap.get(eachPI.Name);
                newOrderedList.add(new selectablePricingItems(eachPI, defaultBillable, isSelected));
            }
            selectablePItems = newOrderedList;
        }
        prevsortExpression = sortExpression;
        gotoFirst();
    }
    
    // method for sorting the two non-standard fields on the selectable table
    // both boolean values (selected and defaultBillableItem)
    public void sortListByAttribute(string queryString){
        list<EDiscovery_PricingItems__c> orderedPI = Database.query(queryString);
        list<selectablePricingItems> newOrderedList = new list<selectablePricingItems>();
        list<selectablePricingItems> attributeTrueList = new list<selectablePricingItems>();
        list<selectablePricingItems> attributeFalseList = new list<selectablePricingItems>();
        
        for(EDiscovery_PricingItems__c eachPI : orderedPI) { 
            Boolean defaultBillable = false;
            If(eachPI.WR_Billable_Types__c != null) {
                defaultBillable = eachPI.WR_Billable_Types__c.contains(wrRecordType);
            }            
            Boolean isSelected = selectionMap.get(eachPI.Name);
            newOrderedList.add(new selectablePricingItems(eachPI, defaultBillable, isSelected));
        }
        
        for(selectablePricingItems selectableItem : newOrderedList) {
            Boolean attribute = false;
            if(sortExpression == 'Selected') {
                attribute = selectableItem.selected;
            } else {
                attribute = selectableItem.defaultBillableItem;
            }
            if(attribute) { 
                attributeTrueList.add(selectableItem);
            } else {
                attributeFalseList.add(selectableItem);
            }
        }
        if(sortDirection == 'ASC') {
            selectablePItems = attributeFalseList;
            selectablePItems.addAll(attributeTrueList);
        } else {
            selectablePItems = attributeTrueList;
            selectablePItems.addAll(attributeFalseList);
        }
        rebuildVisibleList();        
    }

    // pass in the set of all Pricing Items and the set of ones associated to the Billable Items already on the
    // Work Request, return only the ones from the first set that are not in the second.
    public set<string> getUnbilledPricingItems(set<string> pricingItemSet, set<string> alreadyBilledPricingItems){
        boolean removedBilledPItems = pricingItemSet.removeAll(alreadyBilledPricingItems);
        return pricingItemSet;
    }

    // return a map of Pricing Item name to the parent Projects Pricing Library Id that is associated to it
    public map<string, Id> buildItemToLibraryMap() {
        map<string, Id> itemToLibraryMap = new map<string, Id>();
        for(EDiscovery_PricingLibrary__c eachLibrary : [select Id, Pricing_Item_ID__c 
                                                        from EDiscovery_PricingLibrary__c where Project__c = :projId]) {
            itemToLibraryMap.put(eachLibrary.Pricing_Item_ID__c, eachLibrary.Id);
        }
        return itemToLibraryMap;
    }
    
    // Attempt to create new Billable Item records from the
    // selections.
    public PageReference createNewBillableItemsFromSelection() {
        list<EDiscovery_BillableItems__c> biToCreate = createNewBillableItems();
        try{
            insert biToCreate;
            return cancel();
        } catch(Exception exc) {
            recordError = Pulse_Utils.trimErrorMessage(exc.getMessage(), 'EXCEPTION: ');
            newRecordError = true;
            return null;
        }
    }

    public list<EDiscovery_BillableItems__c> createNewBillableItems() {
        list<EDiscovery_BillableItems__c> newBItems = new list<EDiscovery_BillableItems__c>();
        for(selectablePricingItems selectableItem : userChosenPItems) {
            EDiscovery_PricingItems__c pricingItem = selectableItem.item;
            newBItems.add(new EDiscovery_BillableItems__c(PricingItem__c = pricingItem.Id, 
                                                            PricingLibrary__c = pricingItemToLibraryMap.get(pricingItem.Name),
                                                          	WorkRequest__c = wrId));
        }
        return newBItems;
    }
    
    // for each selected Pricing Item add that record to the list
    // that will be translated into new Billable Items.
    public void selectPricingItems() {
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        userChosenPItems = new list<selectablePricingItems>();
        for(EDiscovery_PricingItems__c eachPItem : originalPIList) {
            if(selectionMap.get(eachPItem.Name)) {
                Boolean defaultBillable = false;
                If(eachPItem.WR_Billable_Types__c != null) {
                    defaultBillable = eachPItem.WR_Billable_Types__c.contains(wrRecordType);
                } else {
                    defaultBillable = false;
                }
                userChosenPItems.add(new SelectablePricingItems(eachPItem, defaultBillable, true));                
            }
        }
        newRecordSection = true;
    }
    
    // Method below rebuilds and requeries the list of Pricing Items
    // based on the Material code chosen by the user. The sort Expression
    // and sort direction are retained, but won't have a real impact unless 
    // there are multiple Pricing Items with the same Material code.
    public void filterPricingItems() {
        system.debug('filtering now');
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        // build initial query
        string queryString = 'Select Id, Name, BillableItem__c, Unit__c, Material_Code__c, WR_Billable_Types__c ' +
            					'FROM EDiscovery_PricingItems__c WHERE Id in : originalPIList';
        // add material code sort
        if(materialCode != '-- None --') queryString += ' AND Material_Code__c = \'' + materialCode + '\'';
        system.debug('queryString');
        // sort records as selected by user
        Switch on sortExpression {
            when 'PricingItemID' { 
                if(sortDirection == 'ASC') queryString += ' ORDER BY Name ASC NULLS LAST';
                if(sortDirection == 'DESC') queryString += ' ORDER BY Name DESC NULLS FIRST';
            }
            when 'MaterialCode' {
                if(sortDirection == 'ASC') queryString += ' ORDER BY Material_Code__c ASC NULLS LAST';
                if(sortDirection == 'DESC') queryString += ' ORDER BY Material_Code__c DESC NULLS FIRST';
            }
            when 'BillableItem' {
                if(sortDirection == 'ASC') queryString += ' ORDER BY BillableItem__c ASC NULLS LAST';
                if(sortDirection == 'DESC') queryString += ' ORDER BY BillableItem__c DESC NULLS FIRST';
            }
            when 'Unit' {
                if(sortDirection == 'ASC') queryString += ' ORDER BY Unit__c ASC NULLS LAST';
                if(sortDirection == 'DESC') queryString += ' ORDER BY Unit__c DESC NULLS FIRST';
            }
            when 'DefaultItem','Selected' {
                sortListByAttribute(queryString);
            }
        }
        // recreate selectable item list based on query results
        if(sortExpression != 'DefaultItem' && sortExpression != 'Selected'){
            system.debug('process');
            list<selectablePricingItems> newOrderedList = new list<selectablePricingItems>();
            list<EDiscovery_PricingItems__c> orderedPI = Database.query(queryString);
            system.debug('we found ' + orderedPI.size() + ' records');
            // rebuild the list of selectable Items based on the new query results
            for(EDiscovery_PricingItems__c eachPI : orderedPI) { 
                Boolean defaultBillable = false;
                If(eachPI.WR_Billable_Types__c != null) {
                    defaultBillable = eachPI.WR_Billable_Types__c.contains(wrRecordType);
                }            
                Boolean isSelected = selectionMap.get(eachPI.Name);
                newOrderedList.add(new selectablePricingItems(eachPI, defaultBillable, isSelected));
            }
            selectablePItems = newOrderedList;
        }
        // construct page view list on first page 
        gotoFirst();
    }
    
    // reset the necessary lists and variables so new selections can be made.
    public void updateItemSelection() {
        newRecordError = false;
        recordError = null;
        // clear the list of chosen Pricing Item.
        userChosenPItems.clear();
        /* // removed in favor of presenting the user with the records they selected
        // de-select each selectable Pricing Item record.
        for(selectablePricingItems eachPItem : selectablePItems){ 
            eachPItem.selected = false;
			selectionMap.put(eachPItem.item.Name, false);
        }
		*/
        materialCode = '-- None --';
        sortExpression = 'Selected';
        prevSortExpression = 'Selected';
        sortDirection = 'ASC';
        updateTable();
        // update the variable that determines which section of the page is shown.
        newRecordSection = false;
    }
    
    public void gotoFirst() {
        getLastPage();
        system.debug('Page size is now: ' + pageSize);
        for(SelectablePricingItems displayItem : pageItems){
            // any change to the current page or size of the page requires
            // updating the map of items and their selected state to maintain 
            // users choices
            selectionMap.put(displayItem.item.Name, displayItem.selected);
        }
        pageNumber = '1';
        pageItems = new List<SelectablePricingItems>();
        for(Integer x = 0; x < Integer.valueOf(pageSize); x++){
            if(x <= selectablePItems.size() - 1){
	            Boolean selectedValue = selectionMap.get(selectablePItems[x].item.Name);
    	        pageItems.add(new selectablePricingItems(selectablePItems[x].item, selectablePItems[x].defaultBillableItem, selectedValue));
            }
        }
        disablePrevious = true;
        disableNext = (selectablePItems.size() <= Integer.valueOf(pageSize));
    }
    
    public void gotoPrevious() {
        Integer page = Integer.valueOf(pageNumber);
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        pageNumber = string.valueOf(page - 1);
        disableNext = false;
        if(pageNumber == '1') disablePrevious = true;
        rebuildVisibleList();
    }
    
    public void gotoNext() {
        Integer page = Integer.valueOf(pageNumber);
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        pageNumber = string.valueOf(page + 1);
        disablePrevious = false;
        if(pageNumber == lastPage) disableNext = true;
        rebuildVisibleList();
    }
    
    // sets the page number to the last page and
    // run
    public void gotoLast() {
        for(selectablePricingItems PIChoice : pageItems){
            selectionMap.put(PIChoice.item.Name, PIChoice.selected);
        }
        pageNumber = lastPage;
        disableNext = true;
        if(pageNumber != '1') disablePrevious = false;
        rebuildVisibleList();
    }

	// method finds the records whose index is in the new range
	// and puts them in the list that is shown to the users    
    public void rebuildVisibleList() {
        Integer page = Integer.valueOf(pageNumber);
        Integer pgSize = Integer.valueOf(pageSize);
        Integer startIndex = (page == 1 ? 0 : pgSize * (page - 1));
        pageItems = new list<SelectablePricingItems>();
        for(Integer x = startIndex, countAdded = 0; countAdded < pgSize; x++){
            if(x < selectablePItems.size()) {
                SelectablePricingItems listItem = selectablePItems[x];
                pageItems.add(new SelectablePricingItems(listItem.item, listItem.defaultBillableItem, selectionMap.get(listItem.item.Name)));
                countAdded += 1;
            } else {
                break;
            }
        }
    }
    
    // respond to users changing the number of records they want to see on a page
    // sends the user to the first page
    public void resizePage(){
        gotoFirst();
    }

    // check for the 'MassAddBi' parameter added to the url through the Mass Create
    // button and decide if the user should go to the Visualforce page or to the standard
    // single record creation page.
    public PageReference redirect(){
        if(pageParams.keySet().contains('MassAddBi')){ // continue to VF page
            return null;
        } else { // send user to New record page
            return getStandardNewRecordURL();
        }
    }
    
    // return the new record standard page
    public PageReference getStandardNewRecordURL(){
        string url = '/' + Pulse_Utils.getObjectKeyPrefix('EDiscovery_BillableItems__c') + '/e?';
        system.debug(url);
        system.debug(wrId != null);
        // if(wrId != null) { 
        	url += wrIdKey + '=' + wrId + '&';
        	url += wrNameKey + '=' + wrName + '&';
        	url += 'retURL=/' + wrId + '&nooverride=1';
    	// }
    	return new PageReference(url);
    }    

    // cancel out to the Work Request detail page
    public PageReference cancel(){
        return new System.PageReference('/'+wrId);
    }

    // selectable class for Pricing Items also holds 
    // non-standard attribute that identifies Pricing Items
    // that would be automatically created when a Work Request
    // was created new.
    public class selectablePricingItems {
        public EDiscovery_PricingItems__c item {get; set;}
        public boolean selected {get; set;}
        public boolean defaultBillableItem {get; set;}
    
        public selectablePricingItems(EDiscovery_PricingItems__c pricingItem, Boolean defaultCreated, Boolean isSelected){
            item = pricingItem;
            defaultBillableItem = defaultCreated;
            selected = isSelected;
        }
    }
}