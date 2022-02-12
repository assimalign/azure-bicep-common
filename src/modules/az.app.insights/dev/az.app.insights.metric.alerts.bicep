



resource temp 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  properties: {
    criteria:  {
       'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
        allOf: [
           {
             name: 
             alertSensitivity: 
             failingPeriods: {
               minFailingPeriodsToAlert: 
               numberOfEvaluationPeriods: 
             }
             timeAggregation: 
             metricName: 
             criterionType: 'DynamicThresholdCriterion'
             operator: 
           }
        ]
    }
    severity: 
    windowSize:  
    enabled: 
    evaluationFrequency:  
    scopes: 
     
  }
}
