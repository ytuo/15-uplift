import itertools
import multiprocessing as mp
import pandas as pd
import gurobipy as gp
from gurobipy import Model, GRB
from pathlib import Path
from tqdm import tqdm


directory = Path.cwd()
FactoryCost = pd.read_csv(directory / 'optimization/factory_estimate.csv')
FactoryCost.set_index('CoC_Number', inplace=True)

coc_distance_matrix = pd.read_csv(directory / 'optimization/coc_distance_matrix.csv')
CoC_populations = pd.read_csv(directory / 'optimization/Coc_populations.csv')
cocs = CoC_populations['CoC_Number'].tolist()
CoC_populations.set_index('CoC_Number', inplace=True)

input_data = {
    'factory cost' : FactoryCost,
    'factory production limit': 5_000,
    'coc distance matrix' : coc_distance_matrix,
    'coc populations' : CoC_populations
}

# Example discretized parameter grid
param_grid = {
    "thu_price" : [3_000, 4_000, 5_000, 6_000, 7_000, 8_000, 9_000, 10_000],
    "factory_scaler" : [30, 33, 36, 39],
    "shipping_cost": [1, 2, 5],
    "budget" : [50_000_000, 100_000_000, 150_000_000, 200_000_000]
}

# param_grid = {
#     "thu_price" : [3_000, 5_000],
#     "factory_scaler" : [30],
#     "shipping_cost": [1],
#     "budget" : [50_000_000]
# }

M = 9e12

def make_grid(grid_dict):
    keys = list(grid_dict.keys())
    for vals in itertools.product(*(grid_dict[k] for k in keys)):
        yield dict(zip(keys, vals))

def build_and_solve(params):
    """
    Build and solve Uplift optimization problem for sensitivity analysis
    """
    m = Model()
    m.setParam("OutputFlag", 0)
    m.setParam("Threads", 1)

    THUCost = params['thu_price']
    THUShippingPerMile = params['shipping_cost']
    FactoryCost = input_data['factory cost']
    FactoryCost = FactoryCost * params['factory_scaler']/36
    THU_Factory_Limit = 5_000
    TotalBudget = params['budget']

    CoC_populations = input_data['coc populations']
    numCoCs = len(CoC_populations)
    
    # Number of cities
    NumCities = numCoCs

    # Number of factory locations available (equivalent to cities)
    # todo: rename var
    NumFactories = numCoCs

    indices = range(len(CoC_populations))
    indexToCityDict = dict(zip(indices, cocs))
    def indexToCity(index):
        return indexToCityDict[index]

    numCoCs = len(CoC_populations)

    # Decision variables
    # How many homes to place per city
    THU = m.addVars((t for t in range(0, NumCities)), lb=0, name="THUQuantityPerCity")

    # Where to place factories (also # of factories)
    Factory = m.addVars((t for t in range(0, NumFactories)), vtype=GRB.BINARY, name="FactoryLocations")

    # How many THUs shipped from a given factory
    THUShippedFromFactory = m.addMVar((NumCities, NumFactories), name="ClosestFactory", lb=0)

    # Constraints
    # Budget constraint
    # sum cost of all the THUs + 
    # sum cost of all the factories + 
    # sum cost of transportation of THUs from all the factories = # produced in city * closest factory * distance to factory * shipping cost per mile
    budgetConstr = m.addConstr((sum(THU[cityIndex]*THUCost for cityIndex in range(0, NumCities)) + 
                                sum(FactoryCost.iloc[factory]['microhome_cost']*Factory[factory] for factory in range(NumFactories)) +
                                sum(THUShippedFromFactory[(cityIndex, factory)]*coc_distance_matrix.iloc[cityIndex, factory]*THUShippingPerMile 
                                for cityIndex in range(NumCities) for factory in range(NumFactories))) <= TotalBudget, name='BudgetConstr')

    # Unhoused population (allocate no more than # unhoused)
    popConstr = m.addConstrs(THU[cityIndex] <= CoC_populations.iloc[cityIndex] for cityIndex in range(0, NumCities))

    # sum of THUs shipped needs to equal THUs in location
    THUTotal = m.addConstrs(sum(THUShippedFromFactory[cityIndex][factoryIndex] for factoryIndex in range(NumFactories)) == THU[cityIndex] for cityIndex in range(NumCities))

    # enforce no THU production if factory not selected
    THUProdatFactory = m.addConstrs(THUShippedFromFactory[cityIndex][factoryIndex] <= M*Factory[factoryIndex] for cityIndex in range(NumCities) for factoryIndex in range(NumFactories))
    FactoryLimit = m.addConstrs(sum(THUShippedFromFactory[cityIndex][factoryIndex] for cityIndex in range(NumCities)) <= THU_Factory_Limit for factoryIndex in range(NumFactories))

    # Todo: max and min # THUs per factory

    # There must be at least one factory in total
    factoryConstr = m.addConstr(sum(Factory[factory] for factory in range(NumFactories)) >= 1)

    m.setObjective(sum(THU[city] for city in range(0, NumCities)), gp.GRB.MAXIMIZE)
    
    m.update()

    m.optimize()

    if m.status == GRB.OPTIMAL:
        THUExpense = sum(THU[cityIndex].x*THUCost for cityIndex in range(0, NumCities))
        FactoryExpense = sum(FactoryCost.iloc[factory]['microhome_cost']*Factory[factory].x for factory in range(NumFactories))
        shipCost = sum(THUShippedFromFactory[cityIndex][factory].x*coc_distance_matrix.iloc[cityIndex, factory]*THUShippingPerMile for cityIndex in range(NumCities) for factory in range(NumFactories))
        return {
            **params,
            "status": m.status,
            "THUs": m.objVal,
            "Factories": sum([Factory[i].x for i in Factory]),
            "Cost": THUExpense + FactoryExpense + shipCost,
        }
    else:
        return {**params, "status": m.status, "obj_val": None, "x": None, "sold": None}

def worker_run(params):
    """Wrapper for multiprocessing."""
    return build_and_solve(params)

if __name__ == "__main__":

    grid = list(make_grid(param_grid))
    print(f"Total scenarios: {len(grid)}")

    # results = []
    # for i, params in enumerate(tqdm(grid, desc="Running scenarios")):
    #     print(f"case: {i}, thu price: {params['thu_price']}, factory scaler: {params['factory_scaler']}, shipping cost: {params['shipping_cost']}, budget: {params['budget']}")
    #     result = build_and_solve(params)
    #     results.append(result)

    with mp.Pool(processes=min(len(grid), 10)) as pool:
        # results = pool.map(worker_run, grid)
        results = list(tqdm(pool.imap(worker_run, grid), total=len(grid)))


    df = pd.DataFrame(results)
    df.to_csv("sensitivity_results.csv", index=False)
    print(df)
