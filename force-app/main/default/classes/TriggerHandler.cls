public virtual class TriggerHandler {
    
    // static map of handlername, times run() was invoked
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;
    
    @TestVisible
    private static Map<String, List<Trigger_Handler__mdt>> objectToHandlerMap;
    
    // the current context of the trigger, overridable in tests
    @TestVisible
    private TriggerContext context;
    
    // the current context of the trigger, overridable in tests
    @TestVisible
    private Boolean isTriggerExecuting;
    
    // static initialization
    static {
        loopCountMap = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
        objectToHandlerMap = new Map<String, List<Trigger_Handler__mdt>>();
    }
    
    // constructor
    public TriggerHandler() {
        this.setTriggerContext();
        this.setTriggerHandlers();
    }
    
    private void setTriggerHandlers(){
        if(objectToHandlerMap.size() == 0){
            for(Trigger_Handler__mdt handler : [SELECT Id, Object_Name__r.QualifiedApiName, ApexHandlerClassName__c,
                                                Before_Insert__c, Before_Update__c, Before_Delete__c,
                                                After_Insert__c, After_Update__c, After_Delete__c, After_Undelete__c
                                                FROM Trigger_Handler__mdt 
                                                WHERE Active__c = true 
                                                ORDER BY Load_Order__c]){
                    System.debug('handler.SFTF__Object_Name__r -- ' + handler.SFTF__Object_Name__r);
                    if(!objectToHandlerMap.containsKey(handler.SFTF__Object_Name__r.QualifiedApiName)){
                        objectToHandlerMap.put(handler.SFTF__Object_Name__r.QualifiedApiName, new List<Trigger_Handler__mdt>());
                    }
                    objectToHandlerMap.get(handler.SFTF__Object_Name__r.QualifiedApiName).add(handler);
            }
        }
    }
    
/***************************************
* public instance methods
***************************************/
    
    // main method that will be called during execution
    public void run() {
        if(!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
        }
        
        SObjectType triggerType = Trigger.isDelete ? Trigger.old.getSObjectType() : Trigger.new.getSObjectType();
        String objectName = triggerType.getDescribe().getName();
		
        System.debug('objectToHandlerMap -- ' + objectToHandlerMap.keySet());
        if(objectToHandlerMap.containsKey(objectName)){
            for(Trigger_Handler__mdt handler : objectToHandlerMap.get(objectName)){
                Type classType = Type.forName(handler.ApexHandlerClassName__c);
                
                if(classType != null) {     
                    Object classInstance = classType.newInstance();
                    
                    //The objects we create dynamically need to implement the TDTM_Runnable interface
                    if(classInstance instanceof TriggerHandler) {
                        TriggerHandler classToRunInstance = (TriggerHandler)classInstance;
                        
                        if(!classToRunInstance.validateRun()) {
                            continue;
                        }
                        
                        classToRunInstance.addToLoopCount();
                        
                        // dispatch to the correct handler method
                        switch on this.context {
                            when BEFORE_INSERT {
                                if(handler.Before_Insert__c){
                                	classToRunInstance.beforeInsert();
                                }
                            }
                            when BEFORE_UPDATE {
                                if(handler.Before_Update__c){
                                	classToRunInstance.beforeUpdate();
                                }
                            }
                            when BEFORE_DELETE {
                                if(handler.Before_Delete__c){
                                	classToRunInstance.beforeDelete();
                                }
                            }
                            when AFTER_INSERT {
                                if(handler.After_Insert__c){
                                	classToRunInstance.afterInsert();
                                }
                            }
                            when AFTER_UPDATE {
                                if(handler.After_Update__c){
                                	classToRunInstance.afterUpdate();
                                }
                            }
                            when AFTER_DELETE {
                                if(handler.After_Delete__c){
                                	classToRunInstance.afterDelete();
                                }
                            }
                            when AFTER_UNDELETE {
                                if(handler.After_Undelete__c){
                                	classToRunInstance.afterUndelete();
                                }
                            }
                        }
                        
                    } else {
                        System.debug(LoggingLevel.WARN, '****The class '+ handler.ApexHandlerClassName__c +' does not implement the required Trigger handler.');
                    }
                } else {
                    System.debug(LoggingLevel.WARN, '****'+handler.ApexHandlerClassName__c+' is not a valid Apex class');
                }
            }
        }
    }
    
    
    
    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if(!TriggerHandler.loopCountMap.containsKey(handlerName)) {
            TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            TriggerHandler.loopCountMap.get(handlerName).setMax(max);
        }
    }
    
    public void clearMaxLoopCount() {
        this.setMaxLoopCount(-1);
    }
    
    /***************************************
* public static methods
***************************************/
    
    public static void bypass(String handlerName) {
        TriggerHandler.bypassedHandlers.add(handlerName);
    }
    
    public static void clearBypass(String handlerName) {
        TriggerHandler.bypassedHandlers.remove(handlerName);
    }
    
    public static Boolean isBypassed(String handlerName) {
        return TriggerHandler.bypassedHandlers.contains(handlerName);
    }
    
    public static void clearAllBypasses() {
        TriggerHandler.bypassedHandlers.clear();
    }
    
    /***************************************
* private instancemethods
***************************************/
    
    @TestVisible
    private void setTriggerContext() {
        this.setTriggerContext(null, false);
    }
    
    @TestVisible
    private void setTriggerContext(String ctx, Boolean testMode) {
        if(!Trigger.isExecuting && !testMode) {
            this.isTriggerExecuting = false;
            return;
        } else {
            this.isTriggerExecuting = true;
        }
        
        if((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) || (ctx != null && ctx == 'before insert')) {
            this.context = TriggerContext.BEFORE_INSERT;
        } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) || (ctx != null && ctx == 'before update')){
            this.context = TriggerContext.BEFORE_UPDATE;
        } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) || (ctx != null && ctx == 'before delete')) {
            this.context = TriggerContext.BEFORE_DELETE;
        } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) || (ctx != null && ctx == 'after insert')) {
            this.context = TriggerContext.AFTER_INSERT;
        } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) || (ctx != null && ctx == 'after update')) {
            this.context = TriggerContext.AFTER_UPDATE;
        } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) || (ctx != null && ctx == 'after delete')) {
            this.context = TriggerContext.AFTER_DELETE;
        } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) || (ctx != null && ctx == 'after undelete')) {
            this.context = TriggerContext.AFTER_UNDELETE;
        }
    }
    
    // increment the loop count
    @TestVisible
    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if(TriggerHandler.loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName).increment();
            if(exceeded) {
                Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
            }
        }
    }
    
    // make sure this trigger should continue to run
    @TestVisible
    private Boolean validateRun() {
        if(!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
        }
        return !TriggerHandler.bypassedHandlers.contains(getHandlerName());
    }
    
    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substring(0,String.valueOf(this).indexOf(':'));
    }
    
    /***************************************
* context methods
***************************************/
    
    // context-specific methods for override
    @TestVisible
    protected virtual void beforeInsert(){}
    @TestVisible
    protected virtual void beforeUpdate(){}
    @TestVisible
    protected virtual void beforeDelete(){}
    @TestVisible
    protected virtual void afterInsert(){}
    @TestVisible
    protected virtual void afterUpdate(){}
    @TestVisible
    protected virtual void afterDelete(){}
    @TestVisible
    protected virtual void afterUndelete(){}
    
    /***************************************
* inner classes
***************************************/
    
    // inner class for managing the loop count per handler
    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;
        
        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }
        
        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }
        
        public Boolean increment() {
            this.count++;
            return this.exceeded();
        }
        
        public Boolean exceeded() {
            return this.max >= 0 && this.count > this.max;
        }
        
        public Integer getMax() {
            return this.max;
        }
        
        public Integer getCount() {
            return this.count;
        }
        
        public void setMax(Integer max) {
            this.max = max;
        }
    }
    
    // possible trigger contexts
    @TestVisible
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
            AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE,
            AFTER_UNDELETE
            }
    
    // exception class
    public class TriggerHandlerException extends Exception {}
    
}