stake_amount = 1000  
apy_rate = 20  
percentage_denominator = 100  
days_in_year = 365  

def calculate_rewards(stake_amount, apy_rate, days_staked, days_in_year):
    daily_rate = apy_rate / days_in_year
    rewards = stake_amount * (daily_rate / 100) * days_staked
    return rewards

rewards_year = calculate_rewards(stake_amount, apy_rate, days_in_year, days_in_year)
print(f"1 yıl sonunda : {rewards_year} ")

rewards_180_days = calculate_rewards(stake_amount, apy_rate, 180, days_in_year)
print(f"180 gün sonunda : {rewards_180_days} ")

rewards_30_days = calculate_rewards(stake_amount, apy_rate, 30, days_in_year)
print(f"30 gün sonunda : {rewards_30_days} ")
