-- Fix foreign key constraint on wishlist_items to allow cascade delete
-- The error "update or delete on table 'products' violates foreign key constraint 'wishlist_items_product_id_fkey'"
-- indicates that items in a wishlist are blocking product deletion.

ALTER TABLE wishlist_items
DROP CONSTRAINT IF EXISTS wishlist_items_product_id_fkey;

ALTER TABLE wishlist_items
ADD CONSTRAINT wishlist_items_product_id_fkey
FOREIGN KEY (product_id)
REFERENCES products(id)
ON DELETE CASCADE;
