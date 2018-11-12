function T_recover=main_noisyor1bit_TC(TE,E,p_cc,doingmax,doing1bit,f,fprime,iter,alternations,infbound)

%main_noisyor1bit_TC: outputs T_recover from the measurements TE. 

%Inputs:
%TE:       The mesurements tensor on the observed indices(E) can be 1-bit or noisy
%E:        Binary tensor indicaiting observed indices. 
%p_cc:     Fraction of observed sampled used for cross validation
%doingmax: Set to 1 for max-qnorm constrained TC. 0 for factor-fron constrained TC
%doing1bit:Set to 1 for 1-bit measurements. 0 for noisy(or clean partial) measurements. 

%f, fprime:f and fprime are used for defining obsevarions in 1-bit TC 
%check https://arxiv.org/abs/1804.00108 : Learning tensors from partial binary measurements

%iter:     Number of iteration for each alternation subproblem
%alternations: Number of alternation
%infbound .  : Infinity norm of the original tensor (this is just useful
%when used for recoverung the original tensor in 1bit TC) don't use for
%recovering the sign of the tensor 

n=max(size(TE));
rmin=min(2*n,200);
rmax=min(2*n,200);

idx=find(E(:)==1)';
idx=idx(randperm(length(idx)));

doingnuclear=1-doingmax;


doingend=1;  %% If set to 1, brings back the cross validation observations at the end (when the optimal bound is chosen)
             %  and runs the recovery algorithm with all the measurements

maxiter=4;  %% number of times the five-point algorithm is ran

constraint_bound_max=20+90*(doingnuclear);
constraint_bound_low=0.02;
num_cuts=9; %% The initial number of cuts. Anything larger than 5 results in finer partiotion of constraint bound range


params_init=[];
idxcc=idx(1:floor(p_cc*length(idx)));                 %% Cross validation indices for chosing the optimal bound
idxc= idx(floor(p_cc*length(idx))+1:length(idx));     %% Training indices

m=length(idx);



params_init.init=-1;


[Drcur,  params] = Alt_TC_1bitnoisy(TE, E, rmin,rmin, f, fprime, idx,idxcc,iter,infbound,constraint_bound_max ,params_init,alternations,p_cc,doing1bit,doingmax);



params_opt=params;


constraint_bound_max=max(params.res,0.4);

if doing1bit
    five_idxcc_error(num_cuts)= logObjectiveGeneral(Drcur(:),TE(:),idxcc,f,fprime)
    five_idxc_error(num_cuts)= logObjectiveGeneral(Drcur(:),TE(:),idxc,f,fprime)
else
    five_idxcc_error(num_cuts)= norm(Drcur(idxcc)-TE(idxcc))^2
    five_idxc_error(num_cuts)=norm(Drcur(idxc)-TE(idxc))^2
end


five_overall_error(num_cuts)=0.1*five_idxc_error(num_cuts)*(1-p_cc) + five_idxcc_error(num_cuts) * (p_cc)*(1+(1/p_cc-1))
f_opt=five_idxcc_error(num_cuts);
Dropt=Drcur;
params_opt=params;
bounds_five_points=linspace(constraint_bound_low,constraint_bound_max,num_cuts)

%%
for i=1:(num_cuts-1)
    i
    paramsin=[];
    paramsin.init=-1;
    
    [Drcur,  params] = Alt_TC_1bitnoisy(TE, E, rmin,rmin, f, fprime, idx,idxcc,iter,infbound,bounds_five_points(i) ,paramsin,alternations,p_cc,doing1bit,doingmax);
    
    
    
    five_Mhat_max{i} = Drcur;
    if doing1bit
        five_idxcc_error(i)= logObjectiveGeneral(Drcur(:),TE(:),idxcc,f,fprime)
        five_idxc_error(i)= logObjectiveGeneral(Drcur(:),TE(:),idxc,f,fprime)
    else
        five_idxcc_error(i)= norm(Drcur(idxcc)-TE(idxcc))^2
        five_idxc_error(i)=norm(Drcur(idxc)-TE(idxc))^2
    end
    
    five_overall_error(i)=0.1*five_idxc_error(i)*(1-p_cc) + five_idxcc_error(i) * (p_cc)*(1+(1/p_cc-1))
    
    if five_idxcc_error(i)< f_opt
        
        params_opt=params;
        f_opt=five_idxcc_error(i);
        Dropt=Drcur;
    end
    
    if i>2 && five_overall_error(i)>2*min(five_overall_error(1:i-1))
        five_overall_error(i+1:end)=1000000;
        break;
    end
    
end


for iterations=1:maxiter
    iterations
    
    [val,index]=min(five_overall_error);
    while index>2 && five_overall_error(index)==five_overall_error(index-1)
        index=index-1;
    end
    if index==num_cuts
        index=num_cuts-1;
    elseif index==1
        index=2;
    end
    
    five_points_copy(1)=bounds_five_points(index-1);
    five_cc_copy(1)=five_idxcc_error(index-1);
    five_c_copy(1)=five_idxc_error(index-1);
    five_quality_copy(1)=five_overall_error(index-1);
    
    five_points_copy(3)=bounds_five_points(index);
    five_cc_copy(3)=five_idxcc_error(index);
    five_c_copy(3)=five_idxc_error(index);
    five_quality_copy(3)=five_overall_error(index);
    
    five_points_copy(5)=bounds_five_points(index+1);
    five_cc_copy(5)=five_idxcc_error(index+1);
    five_c_copy(5)=five_idxc_error(index+1);
    five_quality_copy(5)=five_overall_error(index+1);
    
    bounds_five_points=[];
    five_overall_error=[];
    
    bounds_five_points=five_points_copy;
    five_idxcc_error=five_cc_copy;
    five_idxc_error=five_c_copy;
    five_overall_error=five_quality_copy;
    
    for j=[2,4]
        
        bounds_five_points(j)=0.5*bounds_five_points(j-1)+0.5*bounds_five_points(j+1)
        paramsin=[];
        paramsin.init=-1;
        
        
        [Drcur,  params] =Alt_TC_1bitnoisy(TE, E, rmin,rmin, f, fprime, idx,idxcc,iter,infbound,bounds_five_points(j) ,paramsin,alternations,p_cc,doing1bit,doingmax);
        
        
        
        if doing1bit
            five_idxcc_error(j)= logObjectiveGeneral(Drcur(:),TE(:),idxcc,f,fprime);
            five_idxc_error(j)= logObjectiveGeneral(Drcur(:),TE(:),idxc,f,fprime);
        else
            five_idxcc_error(j)= norm(Drcur(idxcc)-TE(idxcc))^2
            five_idxc_error(j)=norm(Drcur(idxc)-TE(idxc))^2
        end
        
        five_overall_error(j)=0.1*five_idxc_error(j)*(1-p_cc) + five_idxcc_error(j) * (p_cc)*(1+(1/p_cc-1))
        
        if five_idxcc_error(j)< f_opt
            params_opt=params;
            f_opt=five_idxcc_error(j);
            Dropt=Drcur;
            
            
        end
        
        
    end
    num_cuts=5;
end

params=params_opt;
constraint_bound_max=params_opt.res;





params_opt=params;


V=params_opt.factors;
T_recover=cpdgen(V);

paramsin.init=-1;


if doingend
    '**********'
    'final regularization bound chosen'
    params_opt.res
    
    [Drcur,  params_opt] = Alt_TC_1bitnoisy(TE, E, rmin,rmax, f, fprime, idx,[],2*iter,infbound,params_opt.res ,paramsin,2*alternations,p_cc,doing1bit,doingmax);
    if doing1bit
        fc_final= logObjectiveGeneral(Drcur(:),TE(:),idx,f,fprime);
    else
        fc_final=norm(Drcur(idx)-TE(idx))^2;
    end
    
    V=params_opt.factors;
    T_recover=cpdgen(V);
    
    for rep=1:4
        
        [Drcur,  params] = Alt_TC_1bitnoisy(TE, E, rmin,rmin, f, fprime, idx,[],2*iter,infbound,params_opt.res ,paramsin,2*alternations,p_cc,doing1bit,doingmax);
        if doing1bit
            fc= logObjectiveGeneral(Drcur(:),TE(:),idx,f,fprime);
        else
            fc=norm(Drcur(idx)-TE(idx))^2;
        end
        
        
        if fc<fc_final
            fc_final=fc;
            params_opt=params;
        end
    end
    
    
end




V=params_opt.factors;
T_max=cpdgen(V);




T_recover=T_max;
T_recover=max(T_recover,-infbound);
T_recover=min(T_recover,infbound);

