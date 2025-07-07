Sequel.migration do
    change do
        create_table(:posts) do
        primary_key :id
        String :post_title, null: false
        String :post_content, text: true
        String :author_name
        String :published_id
        foreign_key :user_id, :users
        end
    end
end
  