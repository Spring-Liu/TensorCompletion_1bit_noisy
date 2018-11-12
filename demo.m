%%demo.m
%This file contains the code of a simple demo for the tensor completion
%using 1bit or noisy measurements. The algorithms are explained in the
%following papers:

%[1]https://arxiv.org/abs/1711.04965 : Near-optimal sample complexity for convex tensor completion
%accepted to be publoshed in information and inference journal

%[2]https://arxiv.org/abs/1804.00108 : Learning tensors from partial binary measurements
%accepted to be published in IEEE transactions on signal processing

%Copyright 2013, N. Ghadermarzy, Y. Plan, O. Yilmaz

%send any feedback to Navid Ghadermarzy <navidgh68@gmail.com>

%    These codes are distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    see <http://www.gnu.org/licenses/>.

% This demo is a demonstration of the algorithms in the above papers and is not suitable for large problems.

clear all
addpath(genpath(pwd))

%This code is a general version that can do both 1bit or noisy TC controled
%by doing1bit variable
doing1bit=1;

%You can switch between max-qnorm and the factor-frob norm (4.19 in the thesis
%https://open.library.ubc.ca/cIRcle/collections/ubctheses/24/items/1.0371162).
%max-qnorm has been analyzed in the above papers. factor-frob is an estimate of the nuclear-norm 
doingmax=1; %set to 1 for max-qnorm constrained TC and 0 for factor-frob constrained
doingnuclear=1-doingmax;

dim=3; %dimension of the tensor

num_tests=1; %number of tests with same n,p,r
n_values=[30];%[30:10:60]; %values for n size of the tensor
r_values=[10];%[3,5,10]; %rank of the tensor

p_obs_values=[0.5];%[0.1:0.1:1]; %observation percentage. Sampled are drawn uniformly in random.



p_cc=0.1; %pcc is the fraction of samples used for cross validating the constraint bound see[1]

iter=10; %number of iteration for each subproblem. Set to a small number
alternations=10; %number of the times the alternating TC is executed

infbound=1; %the infbound of the tensor. Not necessary for noisy-TC or recovering the signs of entries of 1bitTC see[2]

%necassary for generating 1-bit measurements. Ignore for noisy TC
sigma_f=0.1;
f      = @(x) gausscdf(x,0,sigma_f);
fprime = @(x) gausspdf(x,0,sigma_f);

%res_succes is the number of successful recoveries. A recovery is
%successful if the relativ error is <0.001
res_success=zeros(length(n_values),length(r_values),length(p_obs_values),num_tests);
res_relative_error=zeros(length(n_values),length(r_values),length(p_obs_values),num_tests);


seednum=ceil(10);
strm = RandStream('mt19937ar','Seed',seednum);

for iter_n=1:length(n_values)
    n=n_values(iter_n);
    psize=n^dim;
    for iter_r=1:length(r_values)
        for iter_p=1:length(p_obs_values)
            p_obs=p_obs_values(iter_p);
            num_obs=p_obs*n^dim;
            for test=1:num_tests %lines 75 to 85 prevents unnecessary reruns when generating phase transition plots.
                if iter_n>1 && min(squeeze(res_success(iter_n-1,iter_r,iter_p,:)))>0 %%It already always succeeds with smaller n's
                    res_success(iter_n,iter_r,iter_p,test)=1;
                    res_relative_error(iter_n,iter_r,iter_p,test)=0;
                else if iter_p>1 && min(squeeze(res_success(iter_n,iter_r,iter_p-1,:)))>0 %%It already always succeeds with smaller p's (less measurements)
                        res_success(iter_n,iter_r,iter_p,test)=1;
                    res_relative_error(iter_n,iter_r,iter_p,test)=0;
                else
                    if iter_r>1 && min(squeeze(res_relative_error(iter_n,iter_r-1,iter_p,:)))>1-1e-3 %%It already always fails with smaller r's
                        res_success(iter_n,iter_r,iter_p,test)=0;
                        res_relative_error(iter_n,iter_r,iter_p,test)=1;
                    else
                        r=r_values(iter_r);
                        'n  r test'
                        [n r test]
                        N=n;
                        sizes=n*ones(1,dim);
                        clear U %U is the low rank factors of the tensor
                        for i=1:dim
                            Ugen=rand(strm,N,r)-0.5;
                            U{i}=Ugen;
                        end
                        T=(cpdgen(U)); % generate T from U
                       
                        T=T/max(abs(T(:))); %normalize for simplicity. Not necessary! 
                        
                        dim=length(size(T));
                        
                        E=ones(size(T));  %E eventually saves the indices of the observations
                        TE=ones(size(T));%TE eventually saves the the measurements on E 
                        
                        
                        if doing1bit
                            %Y=sign(T);
                            Y = sign(f(T)-rand(size(T)));
                        else
                            Y=T;
                        end
                        
                        TE_init=TE;
                        
                        rperm=randperm(prod(sizes));
                        
                        num_trains=floor(p_obs*prod(sizes));
                        
                        E((rperm(1:prod(sizes)-num_trains)))=0;
                        TE = Y.*E;
                        
                        
                        T_recovered=main_noisyor1bit_TC(TE,E,p_cc,doingmax,doing1bit,f,fprime,iter,alternations,infbound);
                        'relative error'
                        (norm(T(:)-T_recovered(:))^2)/(norm(T(:))^2)
                        
                        res_relative_error(iter_n,iter_r,iter_p,test)=(norm(T(:)-T_recovered(:))^2)/(norm(T(:))^2);
                        
                        if (res_relative_error(iter_n,iter_r,iter_p,test)>1-1e-3) %%If it completely failed
                            res_relative_error(iter_n,iter_r,iter_p,test)=1;
                        end
                        if (res_relative_error(iter_n,iter_r,iter_p,test)<1e-3) %%Successful recovery
                            res_success(iter_n,iter_r,iter_p,test)=1;
                        end
                    end
                    end
                end
            end
        end
    end
end





