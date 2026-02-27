# frozen_string_literal: true

ActiveAdmin.register_page 'InSales Media' do
  menu parent: 'InSales', label: 'InSales Media', priority: 4,
       if: proc { current_admin_user&.can_access_admin_path?('/admin/insales_media') }

  page_action :update, method: :post do
    setting = InsalesSetting.first_or_initialize
    setting.assign_attributes(
      sync_images_enabled: params[:sync_images_enabled] == '1',
      sync_videos_enabled: params[:sync_videos_enabled] == '1'
    )

    if setting.save
      redirect_to admin_insales_media_path, notice: 'Настройки медиа обновлены.'
    else
      redirect_to admin_insales_media_path, alert: setting.errors.full_messages.to_sentence
    end
  end

  content title: 'InSales Media' do
    setting = InsalesSetting.first || InsalesSetting.new

    panel 'Управление медиа синхронизацией' do
      para 'Images: загрузка изображений в InSales.'
      para 'Video: пока не выгружается в InSales (ограничение API), настройка подготовлена для следующего этапа.'

      div do
        form action: admin_insales_media_update_path, method: :post do
          input type: 'hidden', name: 'authenticity_token', value: form_authenticity_token

          div style: 'margin: 10px 0;' do
            label do
              input type: 'checkbox', name: 'sync_images_enabled', value: '1', checked: setting.sync_images_enabled?
              text_node ' Images'
            end
          end

          div style: 'margin: 10px 0;' do
            label do
              input type: 'checkbox', name: 'sync_videos_enabled', value: '1', checked: setting.sync_videos_enabled?
              text_node ' Video'
            end
          end

          div style: 'margin-top: 14px;' do
            input type: 'submit', value: 'Сохранить', class: 'button'
          end
        end
      end
    end
  end
end
