# %% 

# prototype glmfit


# todo: figure out closs validation
# figure out: param contribution evaluation



import sys
import numpy as np
import pandas as pd  
from scipy.optimize import minimize
from scipy.stats import zscore
import matplotlib.pyplot as plt
from sklearn.model_selection import StratifiedShuffleSplit

sys.path.insert(0, r"C:\Users\Flora\Documents\Github\PinkRigs") 
from Admin.csv_queryExp import format_events
from Analysis.neural.utils.spike_dat import get_binned_rasters


class AVSplit(): 
    """
    example model object that takes certain conditions & parameters and spits out the log odds
    for each class we need to mass the names of the parameters  

    subfunctions:   
    """

    required_parameters = np.array(["aL", "aR","vL","vR","gamma","bias"])
    required_conditions = np.array(["audDiff","visDiff"])

    def __init__(self,is_neural=False):
        """
        optional initialisation for neural model
        """
        self.is_neural = is_neural

    def get_logOdds(self,conditions,parameters):

        nTrials = conditions.shape[0]
        if self.is_neural:
            neural_parameters = parameters[self.required_parameters.size:] # each neuron has its own parameter
            neural_conditions = conditions[:,neural_parameters.size:]
            non_neural_parameters = parameters[:self.required_parameters.size]
            non_neural_conditions = conditions[:,:neural_parameters.size]
            neural_contribution = np.matmul(neural_conditions,neural_parameters)

        else: 
            non_neural_parameters,non_neural_conditions = parameters,conditions
            neural_contribution = 0

        aL = non_neural_parameters[self.required_parameters=='aL']
        aR = non_neural_parameters[self.required_parameters=='aR']
        vL = non_neural_parameters[self.required_parameters=='vL']
        vR = non_neural_parameters[self.required_parameters=='vR']
        gamma = non_neural_parameters[self.required_parameters=='gamma']
        bias = non_neural_parameters[self.required_parameters=='bias']

        visDiff = non_neural_conditions[:,self.required_conditions=="visDiff"]
        audDiff = non_neural_conditions[:,self.required_conditions=="audDiff"]
        visContrast = np.abs(visDiff)
        visSide = np.sign(visDiff)
        audSide = np.sign(audDiff)
        
        a_R = (audSide>0)
        a_L = (audSide<0)
        v_R = (visSide>0) * (visContrast**gamma)
        v_L = (visSide<0) * (visContrast**gamma)
        audComponent = (aR) * a_R - (aL) * a_L
        visComponent = (vR) * v_R - (vL) * v_L
        biasComponent = bias 

        return  np.ravel(audComponent + visComponent + biasComponent) + neural_contribution
    
    def plot(self,parameters,yscale='log',conditions=None,choices=None,ax=None,colors=['b','grey','red'],dataplotkwargs={'marker':'o','ls':''},predpointkwargs ={'marker':'*','ls':''},predplotkwargs={'ls':'-'}):
        """
        plot the model prediction for this specific model
        if the model has neural components we 0 those out
        """
        if ax is None:
            _,ax = plt.subplots(1,1,figsize=(8,8))
        
        if self.is_neural:  
            non_neural_params = parameters[:self.required_parameters.size]
            non_neural_conds = conditions[:,:self.required_conditions.size]
            n_neurons = conditions.shape[1]-self.required_conditions.size
        else: 
            non_neural_params,non_neural_conds = parameters,conditions


        if (conditions is not None) & (choices is not None):
            visDiff = np.ravel(non_neural_conds[:,self.required_conditions=="visDiff"])
            audDiff = np.ravel(non_neural_conds[:,self.required_conditions=="audDiff"])
            Vs = np.unique(visDiff)
            As = np.unique(audDiff)

            Vmesh,Amesh =np.meshgrid(Vs,As)
            for v,a,mycolor in zip(Vmesh,Amesh,colors):
                x = v
                x = np.sign(x)*np.abs(x)**non_neural_params[self.required_parameters=='gamma']
                y  = np.array([np.mean(choices[(visDiff==vi) & (audDiff==ai)]) for vi,ai in zip(v,a)])
                
                logOdds =self.get_logOdds(conditions,parameters)
                pR = np.exp(logOdds) / (1 + np.exp(logOdds))

                y_pred = np.array([np.mean(pR[(visDiff==vi) & (audDiff==ai)]) for vi,ai in zip(v,a)])
                if yscale=='log':
                    y =np.log(y/(1-y))
                    y_pred = np.log(y_pred/(1-y_pred))

                ax.plot(x,y,color=mycolor,**dataplotkwargs)
                ax.plot(x,y_pred,color=mycolor,**predpointkwargs)


        #plotting the prediciton psychometric w\o the neural values  
        nPredPoints = 600  
        Vmodel = np.linspace(-1,1,nPredPoints)
        x_ = np.sign(Vmodel)*np.abs(Vmodel)**non_neural_params[self.required_parameters=='gamma']
        Amodel = np.linspace(-1,1,3)
        for a,mycolor in zip(Amodel,colors):
            conds = np.array((np.ones((nPredPoints))*a,Vmodel)).T
            
            if self.is_neural:
                zeroM = np.zeros((nPredPoints,n_neurons))
                conds = np.concatenate((conds,zeroM),axis=1)

            y_ = self.get_logOdds(conds,parameters)
            if yscale!='log':
                y_ = np.exp(y_) / (1 + np.exp(y_))
            ax.plot(x_,y_,color=mycolor,**predplotkwargs)

        # plot the predicted probabilities alone if there is neural data too...


        if yscale=='log':
            ax.axhline(0,color='k',ls='--')
        else:
            ax.axhline(.5,color='k',ls='--')

        ax.axvline(0,color='k',ls='--')
        plt.show()        


def format_av_trials(ev,spikes=None,t=0.2, onset_time = 'timeline_audPeriodOn'):
    """
    specific function for the av pipeline such that the _av_trials.table is formatted for the glmFit class


    Parameters: 
    ----------
    ev: Bunch
        _av_trials.table
    spikes: Bunch 
        default output of the pipeline
      
    todo: input format contains spikes

    Returns: pd.DataFrame
    """
    ev = format_events(ev)
    maxV = np.max(np.abs(ev.visDiff))
    maxA = np.max(np.abs(ev.stim_audAzimuth))

    df = pd.DataFrame()
    df['visDiff']=ev.visDiff/maxV
    df['audDiff']=ev.stim_audAzimuth/maxA
    df['choice'] = ev.response_direction-1



    # filtering of the data
    # by default we get rid of 
        # nogos  
        # invalid trials (i.e. repeatNum!=1)
        # 30 degree aud azimuth
    # we also can optionally get rid of other trials later... 
    to_keep_trials = ((ev.is_validTrial) & 
                      (ev.response_direction!=0) & 
                      (np.abs(ev.stim_audAzimuth)!=30))


   
    # add choice related activity of it was requested
    if spikes: 
        # tbd
        rt_params = {'rt_min':.03,'rt_max':1.5}
        nID  = [140,130]

        raster_kwargs = {
                'pre_time':t,
                'post_time':0, 
                'bin_size':t,
                'smoothing':0,
                'return_fr':True,
                'baseline_subtract': False, 
        }
        t_on = ev[onset_time]

        resps = np.empty((t_on.size,len(nID)))*np.nan
        r = get_binned_rasters(spikes.times,spikes.clusters,nID,t_on[~np.isnan(t_on)],**raster_kwargs)
        
        resps[~np.isnan(t_on),:] = zscore(r.rasters[:,:,0],axis=0)
        
        # if spikes are used we need to filter extra trials, such as changes of Mind
        no_premature_wheel = (ev.timeline_firstMoveOn-ev.timeline_choiceMoveOn)==0
        no_premature_wheel = no_premature_wheel + np.isnan(ev.timeline_choiceMoveOn) # also add the nogos
        to_keep_trials = to_keep_trials & no_premature_wheel

        if rt_params:
                if rt_params['rt_min']: 
                        to_keep_trials = to_keep_trials & (ev.rt>=rt_params['rt_min'])
                
                if rt_params['rt_max']: 
                        to_keep_trials = to_keep_trials & (ev.rt<=rt_params['rt_max'])   

        # some more sophisticated cluster selection as to what goes into the model
        nrnNames  = ['neuron_%.0d' % n for n in nID]
        df[nrnNames] = pd.DataFrame(resps)


    df = df[to_keep_trials].reset_index(drop=True)



    return df
  


class glmFit(): 

    def __init__(self,trials,model_type='AVSplit',groupby=None):
        """
        function to that checks whether fit can be correctly initialised given the input data.
        Parameters:
        ----------
        trials: pd.DataFrame
            table where each row is trial, columns can be:
                choice (required at all times) i.e. the y (predicted value)
                etc. that will all be treated as predictors (required, given the model, e.g. audDiff,visDiff)
        groupby: str
            when several types of sessions are fitted together, this parameter indexes into the trials
        cv_type: 
            type of cv splitting, default StratifiedCVsplit
        """

        assert 'choice' in trials.columns, 'choice is missing.'

        "X: predictors, y = choices"

        predictors = trials.drop('choice',axis='columns')
        self.predictor_names = list(predictors.columns)

        
        # sepearate the neural predictors
        is_neural_predictor = np.array(['neuron' in p for p in self.predictor_names])
        is_neural_model = any(is_neural_predictor)
        if is_neural_model:
            self.neurons = predictors.values[:,is_neural_predictor]
            non_neural_predictors  = list(predictors.columns[~is_neural_predictor])
            self.predictor_names = non_neural_predictors
            self.n_neurons = sum(is_neural_predictor)
        else:
            self.neurons,self.n_neurons = None,0

        self.model = self.LogOddsModel(model_type,is_neural=is_neural_model)     
        
        # reorder x such that columns are ordered as required by model
        pred_ = np.concatenate([predictors[p].values[:,np.newaxis] for p in self.model.required_conditions  if p!='neuron'],axis=1)
        self.non_neural_predictors = pred_

        # concatenate with the neural predictors that always go behind the other required predictors for the model
        if is_neural_model:
            pred_ = np.concatenate((pred_,self.neurons),axis=1)

        self.conditions = pred_
        self.choices = trials.choice.values

    def generate_param_matrix():
        # used when fitting s everal session types together (i.e. when certain parameters are fixed across sessions while others are modular
        pass 

    def LogOddsModel(self,model_type='AVSplit',**modelkwargs):
        """
        function to select model object and assert whether the model parameters are set up correctly
        Parameters:
        ----------
        model_type: str 

        Returns: 
        ---------
            np.ndarray
            log odds

        todo: redefine model when model contribution is assessed (i.e. fixedparam/freeP business)
        """
        if model_type=='AVSplit':
            model = AVSplit(**modelkwargs)

        assert (np.setdiff1d(self.predictor_names,model.required_conditions).size==0), 'some of the required predictors have not been passsed'
        # set up parameters and bounds        
        nParams = len(model.required_parameters) + self.n_neurons


        model.paramInit = [1] * nParams
        model.paramBounds =  [(-1000,1000)]  * nParams    

        return model
 
    def calculatepHat(self,conditions,params):
        """
        calculate the probability of making each possible choice (i.e. [R L])
        """
        logOdds = self.model.get_logOdds(conditions,params)
        pR = np.exp(logOdds) / (1 + np.exp(logOdds))
        pHat = np.array([1-pR,pR])    # because left choice=0 and thus it needs to be 0th index    
        return pHat    

    def init_data_for_LikeLihood(self,X,y):
        self.X = X
        self.y = y

    def get_Likelihood(self,testParams): 
        # this is what could be looped potentially given if there are several dims y becomes 2D & X becomes 3D
        # and then we just sum over the likelihoods for this we need a paramgenerator function called here        
        
        assert hasattr(self,'X'),'data input was not initialised correctly'

        pHat_calculated = self.calculatepHat(self.X,testParams) # the probability of each possible response 
        responseCalc = self.y # the actual response taken        
        # calculate how likely each of these choisen response was given the model
        logLik = -np.mean(np.log2(pHat_calculated[responseCalc.astype('int'),np.arange(pHat_calculated.shape[1])]))
        return logLik
       
    def fit(self):
        """
        fit the model by minimising the logLikelihood
        i.e. the get_Likelihood function  
        todo: optimse parameters for search
        """
        # if the fitting has not been initialised with a dataset alrady ....
        if not hasattr(self,'X'):
            self.init_data_for_LikeLihood(self.conditions,self.choices)

        fittingObjective = lambda b: self.get_Likelihood(b)
        result = minimize(fittingObjective, self.model.paramInit, bounds=self.model.paramBounds)  
        self.model.paramFit = result.x
        self.model.LogLik = self.get_Likelihood(result.x)
    
    def fitCV(self,**kwargs):

        sss = StratifiedShuffleSplit(random_state=0,**kwargs)
        X = self.conditions
        y = self.choices

        params,logLiks = [],[]
        for train_index, test_index in sss.split(X,y):
            X_train, X_test = X[train_index], X[test_index]
            y_train, y_test = y[train_index], y[test_index]
            self.init_data_for_LikeLihood(X_train,y_train)
            self.fit()
            params.append(self.model.paramFit[np.newaxis,:])
            self.init_data_for_LikeLihood(X_test,y_test)
            logLiks.append(self.get_Likelihood(self.model.paramFit))

        self.model.LogLik=np.mean(logLiks)
        self.model.paramFit = np.mean(np.concatenate(params),axis=0)  

    def visualise(self,**plotkwargs):
        """
        visualise the prediction of the log odds model, given visDiff & audDiff (default visualisation)
        """ 
        self.model.plot(parameters=self.model.paramFit,conditions=self.conditions,choices=self.choices,ax=None,**plotkwargs)
 



# %%