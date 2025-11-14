# link_saver_bot.rb (повний файл)
require 'telegram/bot'
require 'sqlite3'

# === КОНФІГУРАЦІЯ ===
TOKEN = '' # !!! ЗАМІНІТЬ НА ВАШ ТОКЕН !!!

# Налаштування бази даних
DB = SQLite3::Database.new 'links.db'
DB.results_as_hash = true # Зручніше для отримання результатів

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS links (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    tag TEXT NOT NULL
  );
SQL
# =====================

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    user_id = message.from.id
    text = message.text

    case text
    when '/start'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Вітаю! Я бот для збереження посилань. \n\n" \
              "Використовуйте:\n" \
              "  `/save [url] [tag]` – для збереження посилання.\n" \
              "  `/get [tag]` – для отримання посилань за тегом."
      )

    when /^\/save\s+(?<url>\S+)\s+(?<tag>\S+)$/i
      match = text.match(/^\/save\s+(?<url>\S+)\s+(?<tag>\S+)$/i)
      url = match[:url]
      tag = match[:tag].downcase # Зберігаємо теги у нижньому регістрі для зручності пошуку

      begin
        # Запит з плейсхолдерами для безпеки (запобігання SQL-ін'єкціям)
        DB.execute "INSERT INTO links (user_id, url, tag) VALUES (?, ?, ?)", 
                   [user_id, url, tag]
        
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "✅ Посилання **'#{url}'** успішно збережено з тегом **'#{tag}'**.",
          parse_mode: 'Markdown'
        )
      rescue => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "❌ Сталася помилка при збереженні: #{e.message}"
        )
      end

    when /^\/get\s+(?<tag>\S+)$/i
      match = text.match(/^\/get\s+(?<tag>\S+)$/i)
      tag = match[:tag].downcase

      # Пошук посилань для конкретного користувача та тегу
      results = DB.execute "SELECT url FROM links WHERE user_id = ? AND tag = ?", 
                           [user_id, tag]

      if results.empty?
        response = "🤷‍♀️ Посилань з тегом **'#{tag}'** не знайдено."
      else
        list = results.map { |row| "• #{row['url']}" }.join("\n")
        response = "🔗 Знайдені посилання для тегу **'#{tag}'**:\n#{list}"
      end

      bot.api.send_message(
        chat_id: message.chat.id,
        text: response,
        parse_mode: 'Markdown'
      )

    else
      # Обробка невідомих команд або звичайного тексту
      # bot.api.send_message(chat_id: message.chat.id, text: "Невідома команда. Спробуйте /start.")
    end
  end
end