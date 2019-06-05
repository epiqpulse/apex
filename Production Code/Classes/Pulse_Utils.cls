/*
    Name:           Pulse_Test_Helpers.cls
    Description:    This class will hold any general purpose method used in the 
                    functional classes so that any repeatable functions can be
                    called from here and not need to be rewritten. This will allow
                    us to more easily maintain the code, and cuts down on what we 
                    need to establish code coverage for when new code is being written.
     Method List:
                    getFieldValueSet(list<sObject> objectList, string field)
                    getSObjectDefaultRecordType(string objectType)
                    getSObjectRecordTypeMap(string objectType)
                    setFieldToValue(list<sObject> objectList, string field, string value)
                    getBatchSettingsMDT(string batchName)
                    setFieldsToValues(list<sObject> objectList, map<string, string> updateMap)
    				trimErrorMessage(string msg, string tag)


    Date            Version         Author              Summary of Changes  
-----------------------------------------------------------------------------------------------
    12/30/2018      1.0             Jerry Daru          Added method list comment, and batch Metadata
                                                        query method

	02/01/2019		1.1				Jerry Daru			Added method that removed system information 
														from exceptions thrown so they can be displayed
														in a more user friendly way.
-----------------------------------------------------------------------------------------------*/
public class Pulse_Utils {
    // method takes in a list of objects of any type, and the api name of a field on that object. 
    // the return is a set of string values for any record that had a value in that field.
    public static set<string> getFieldValueSet(list<sObject> objectList, string field){
    	set<string> fieldValues = new set<string>();
    	for(sObject each : objectList){
    		if(each.get(field) != '' && each.get(field) != null) fieldValues.add((string)each.get(field));
    	}
    	
    	return fieldValues;
    }
    
    //get the default recordtype Id for the passed in sObject based on the running user.
    public static string getSObjectDefaultRecordType(string objectType){
        string defaultRecordType;
        Schema.DescribeSObjectResult[] describe = Schema.describeSObjects(new String[]{objectType});
        for(Schema.RecordTypeInfo info : describe[0].getRecordTypeInfos()){
            system.debug('record type');
            system.debug(info.getRecordTypeId());
            system.debug('is default');
            system.debug(info.isDefaultRecordTypeMapping());
            system.debug(info.getName());
            if(info.isDefaultRecordTypeMapping() && info.getName() != 'Master'){
                defaultRecordType = string.valueOf(info.getRecordTypeId());
                break;
            }
        }
        system.debug(defaultRecordType + ' being returned.');
        return defaultRecordType;
    }
    
    // create a map of Recordtype Id to record type Name for the given sObject.
    public static map<Id, string> getSObjectRecordTypeMap(string objectType){
        map<Id, string> recordTypeMap = new map<Id, string>();
        
        list<RecordType> RecordTypes = new list<RecordType>([Select Id, SObjectType, Name, IsActive, DeveloperName
                                                             From RecordType Where SObjectType = : objectType 
                                                             And IsActive = true]);
        
        for(RecordType rt : RecordTypes) recordTypeMap.put(rt.Id, rt.Name);
        
        return recordTypeMap;
    }
    
    // method takes in a list of objects of any type, a field name, and a value.
    // It iterates through the given list and sets the given field to the given value.
    public static void setFieldToValue(list<sObject> objectList, string field, string value){
    	for(sObject each : objectList){
            each.put(field, value);
    	}
	}

    // retrieve the Batch settings metadata record for the batch that is running based on the record name
    // this method must query all fields on the metadata record so it can accomodate every batch that will use it.
    public static Batch_Run_Settings__mdt getBatchSettingsMDT(string batchName){
        return [select Label, DeveloperName, Batch_Record_Age__c, Batch_Size__c, 
                Failure_Log_Recipients__c, Record_Age_Description__c, Report_Id__c,
                Send_Results__c, Success_Log_Recipients__c, Use_Success_Recipients__c
                from Batch_Run_Settings__mdt where Label = : batchName][0];
    }

    // method takes in a list of objects of any type, and a map of fields -> values
    // It iterates through the given list and updates and sets the fields to the desired values.
    public static void setFieldsToValues(list<sObject> objectList, map<string, string> updateMap){
    	for(sObject each : objectList){
            for(string key : updateMap.keySet()){
                each.put(key, updateMap.get(key));
            }
    	}
    }
    
    // method takes in a string message and a string that contains
    // the expected system exception output and trims all but the
    // user friendly error message
	Public static string trimErrorMessage(string msg, string tag){
		integer startIndex = msg.indexOf(tag)+ tag.length();
		integer endIndex = msg.indexOf(': [');
        if(startIndex != -1 && endIndex != -1) {
			return msg.substring(startIndex, endIndex);
    	} else {
        	return msg;
    	}
	}
    
    // using describe results return the three character key prefix
    // for the sObject whose name is passed in.
    public static string getObjectKeyPrefix(string objectName) {
        Map<String, Schema.SObjectType> globalDescribeMap  = Schema.getGlobalDescribe() ;
		Schema.SObjectType sObjectType = globalDescribeMap.get(objectName) ;
        Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe() ;
		return describeResult.getKeyPrefix();
    }
}