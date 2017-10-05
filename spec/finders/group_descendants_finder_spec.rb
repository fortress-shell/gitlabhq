require 'spec_helper'

describe GroupDescendantsFinder do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:params) { {} }
  subject(:finder) do
    described_class.new(current_user: user, parent_group: group, params: params)
  end

  before do
    group.add_owner(user)
  end

  describe '#execute' do
    it 'includes projects' do
      project = create(:project, namespace: group)

      expect(finder.execute).to contain_exactly(project)
    end

    it 'does not include archived projects' do
      _archived_project = create(:project, :archived, namespace: group)

      expect(finder.execute).to be_empty
    end

    context 'with a filter' do
      let(:params) { { filter: 'test' } }

      it 'includes only projects matching the filter' do
        _other_project = create(:project, namespace: group)
        matching_project = create(:project, namespace: group, name: 'testproject')

        expect(finder.execute).to contain_exactly(matching_project)
      end
    end
  end

  context 'with nested groups', :nested_groups do
    let!(:project) { create(:project, namespace: group) }
    let!(:subgroup) { create(:group, parent: group) }

    describe '#execute' do
      it 'contains projects and subgroups' do
        expect(finder.execute).to contain_exactly(subgroup, project)
      end

      it 'does not include subgroups the user does not have access to' do
        subgroup.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

        public_subgroup = create(:group, :public, parent: group, path: 'public-group')
        other_subgroup = create(:group, :private, parent: group, path: 'visible-private-group')
        other_user = create(:user)
        other_subgroup.add_developer(other_user)

        finder = described_class.new(current_user: other_user, parent_group: group)

        expect(finder.execute).to contain_exactly(public_subgroup, other_subgroup)
      end

      context 'with a filter' do
        let(:params) { { filter: 'test' } }

        it 'contains only matching projects and subgroups' do
          matching_project = create(:project, namespace: group, name: 'Testproject')
          matching_subgroup = create(:group, name: 'testgroup', parent: group)

          expect(finder.execute).to contain_exactly(matching_subgroup, matching_project)
        end

        it 'does not include subgroups the user does not have access to' do
          _invisible_subgroup = create(:group, :private, parent: group, name: 'test1')
          other_subgroup = create(:group, :private, parent: group, name: 'test2')
          public_subgroup = create(:group, :public, parent: group, name: 'test3')
          other_subsubgroup = create(:group, :private, parent: other_subgroup, name: 'test4')
          other_user = create(:user)
          other_subgroup.add_developer(other_user)

          finder = described_class.new(current_user: other_user,
                                       parent_group: group,
                                       params: params)

          expect(finder.execute).to contain_exactly(other_subgroup, public_subgroup, other_subsubgroup)
        end

        context 'with matching children' do
          it 'includes a group that has a subgroup matching the query and its parent' do
            matching_subgroup = create(:group, name: 'testgroup', parent: subgroup)

            expect(finder.execute).to contain_exactly(subgroup, matching_subgroup)
          end

          it 'includes the parent of a matching project' do
            matching_project = create(:project, namespace: subgroup, name: 'Testproject')

            expect(finder.execute).to contain_exactly(subgroup, matching_project)
          end

          it 'does not include the parent itself' do
            group.update!(name: 'test')

            expect(finder.execute).not_to include(group)
          end
        end
      end
    end
  end
end
