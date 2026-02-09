# frozen_string_literal: true

run = InsalesSyncRun.create!(store_name: 'Тест', started_at: Time.current, status: 'running')
run.update!(processed: 1, created: 1, updated: 0, error_count: 0, finished_at: Time.current, status: 'success')
puts "ok: #{run.id}"
