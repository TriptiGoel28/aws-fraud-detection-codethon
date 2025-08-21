# Additional SageMaker resources for fraud detection

# Data preprocessing script for RCF
resource "aws_s3_object" "preprocessing_script" {
  bucket = "my-secure-bucket-wxj077wp"
  key    = "scripts/preprocess_for_rcf.py"
  content = <<EOF
import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder
import sys

def preprocess_data(input_path, output_path):
    # Read parquet files
    df = pd.read_parquet(input_path)
    
    # Encode categorical variables
    le_country = LabelEncoder()
    le_category = LabelEncoder()
    
    df['country_encoded'] = le_country.fit_transform(df['country'])
    df['category_encoded'] = le_category.fit_transform(df['merchant_category'])
    
    # Select features for RCF (numerical only)
    features = ['amount', 'transaction_hour', 'country_encoded', 'category_encoded']
    
    # Add customer frequency feature
    customer_counts = df['customer_id'].value_counts()
    df['customer_frequency'] = df['customer_id'].map(customer_counts)
    
    # Add day of week
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['day_of_week'] = df['timestamp'].dt.dayofweek
    
    final_features = ['amount', 'transaction_hour', 'country_encoded', 'category_encoded', 'customer_frequency', 'day_of_week']
    
    # Save processed data as CSV for RCF
    df[final_features].to_csv(output_path, index=False, header=False)
    
    print(f"Processed {len(df)} records")
    print(f"Features: {final_features}")

if __name__ == "__main__":
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    preprocess_data(input_path, output_path)
EOF
}