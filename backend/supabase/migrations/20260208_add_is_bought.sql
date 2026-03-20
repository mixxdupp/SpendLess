-- Add is_bought column to products table
ALTER TABLE products 
ADD COLUMN is_bought BOOLEAN DEFAULT false;

-- Create index for faster filtering of bought/tracked items
CREATE INDEX idx_products_is_bought ON products(is_bought);
