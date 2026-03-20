-- Fix RLS policies for price_history to allow cascade delete
-- When a user deletes a product, the ON DELETE CASCADE tries to delete price_history rows.
-- Without a DELETE policy, this fails for non-service-role users.

CREATE POLICY "Users can delete own products price history" ON price_history
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM products
      WHERE products.id = price_history.product_id
      AND products.user_id = auth.uid()
    )
  );

-- Also allow INSERT in case the client needs to log history manually in future
CREATE POLICY "Users can insert own products price history" ON price_history
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM products
      WHERE products.id = price_history.product_id
      AND products.user_id = auth.uid()
    )
  );
