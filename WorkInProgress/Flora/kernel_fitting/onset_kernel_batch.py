# %% 
import sys
import time
sys.path.insert(0, r"C:\Users\Flora\Documents\Github\PinkRigs") 
from pathlib import Path
from Analysis.pyutils.batch_data import get_data_bunch
from Analysis.pyutils.io import save_dict_to_json
#dataset = 'naive-total'
dataset = 'trained-active-curated'
fit_tag = 'additive-fit'



interim_data_folder = Path(r'C:\Users\Flora\Documents\ProcessedData\Audiovisual')
save_path = interim_data_folder / dataset / 'kernel_model' / fit_tag

save_path.mkdir(parents=True,exist_ok=True)

recordings = get_data_bunch(dataset)

from Analysis.neural.src.kernel_model import kernel_model

from kernel_params import get_params


recompute = False
for _,rec_info in recordings.iterrows():
   #  reinitialise the object?
    kernels = kernel_model(t_bin=0.005,smoothing=0.025)
    dat_params,fit_params,eval_params = get_params(dat_set='active')

    output_file = (save_path / ('%s_%s_%.0f_%s.csv' % tuple(rec_info)))
    if not output_file.is_file() or recompute:
        try:
            print('Now attempting to fit %s %s, expNum = %.0f, %s' % tuple(rec_info))
            t0 = time.time()
            kernels.load_and_format_data(**dat_params,**rec_info)
            kernels.fit(**fit_params)
            variance_explained = kernels.evaluate(**eval_params)
            variance_explained.to_csv(output_file)
            print('time to fit-evaluate:',time.time()-t0,'s')
        except:
            pass
    else:
        print('%s %s, expNum = %.0f, %s seems to be already fitted.' % tuple(rec_info))
# save the parameters of fitting
save_dict_to_json(dat_params,save_path / 'dat_params.json')
save_dict_to_json(fit_params,save_path / 'fit_params.json')
save_dict_to_json(eval_params,save_path / 'eval_params.json')


# %%
