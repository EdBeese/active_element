# frozen_string_literal: true

RSpec.describe '/_text_search' do
  describe 'POST /_text_search' do
    before do
      create(:example, id: 1000, email: 'user@example.com')
      create(:example, id: 2000, email: 'other-user@example.com')
      sign_in(create(:user, permissions: ['can_list_dummy_examples'] + permissions))
      post '/_text_search.json', headers: { 'Content-Type' => 'application/json' }, params: params.to_json
    end

    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    let(:authenticity_token) do
      get '/examples'
      document.meta(name: 'csrf-token')[:content]
    end

    let(:params) do
      {
        authenticity_token: authenticity_token,
        model: model,
        attributes: attributes,
        value: value,
        query: query
      }
    end

    let(:model) { 'example' }
    let(:attributes) { ['email'] }
    let(:value) { 'id' }
    let(:query) { 'user@' }

    context 'with correct permission and authorized model/attribute/attribute' do
      let(:permissions) { %w[can_create_dummy_active_element_text_searches] }

      it 'returns matching results' do
        expect(json.fetch(:results)).to eql [{ value: 1000, attributes: ['user@example.com'] }]
      end

      it 'returns 200 OK' do
        expect(response).to have_http_status :ok
      end
    end

    context 'with correct permission and unknown model' do
      let(:permissions) { %w[can_create_dummy_active_element_text_searches] }
      let(:model) { 'unknown_example' }

      it 'returns error message' do
        expect(json[:message]).to eql 'Unpermitted or unavailable search for: ' \
                                      '{ model: unknown_example, attributes: ["email"], value: id }'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context 'with correct permission and unauthorized model' do
      let(:permissions) { %w[can_create_dummy_active_element_text_searches] }
      let(:model) { 'unauthorized_example' }

      it 'returns error message' do
        expect(json[:message]).to eql 'Unpermitted or unavailable search for: ' \
                                      '{ model: unauthorized_example, attributes: ["email"], value: id }'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(response).to have_http_status :unprocessable_entity
      end
    end

    context 'with incorrect permission' do
      let(:permissions) { %w[can_do_other_thing] }
      let(:model) { 'example' }

      it 'returns error message' do
        expect(json[:message])
          .to eql 'Missing permission(s): ["can_create_dummy_active_element_text_searches"]'
      end

      it 'returns 422 Unprocessable Entity' do
        expect(response).to have_http_status :forbidden
      end
    end
  end
end
