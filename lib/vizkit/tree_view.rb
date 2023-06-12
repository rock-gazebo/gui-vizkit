require 'vizkit/vizkit_items'

module Vizkit
    def self.setup_tree_view(tree_view)
        delegator = ItemDelegate.new(tree_view,nil)
        tree_view.setItemDelegate(delegator)
        tree_view.setSortingEnabled true
        tree_view.sortByColumn(0, Qt::AscendingOrder)
        tree_view.setAlternatingRowColors(true)
        tree_view.setContextMenuPolicy(Qt::CustomContextMenu)
        tree_view.setDragEnabled(true)
        tree_view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |pos|
            index = tree_view.index_at(pos)
            next unless index.isValid
            item = tree_view.item_from_index(index)
            item.context_menu(pos,tree_view)
        end

        def tree_view.real_model
            if model.is_a?(Qt::AbstractProxyModel)
                return model.sourceModel
            else
                return model
            end
        end

        def tree_view.item_from_index(index)
            if index.model.is_a?(Qt::AbstractProxyModel)
                return index.model.sourceModel.itemFromIndex(index.model.mapToSource(index))
            else
                return index.model.itemFromIndex(index)
            end
        end

        def tree_view.setModel(model)
            raise ArgumentError,"wrong model type" unless model.is_a? Qt::AbstractItemModel
            super
            connect SIGNAL("collapsed(QModelIndex)") do |index|
                item_from_index(index).collapsed
                item = item_from_index(index.sibling(index.row,1))
                item.collapsed if item.is_a? VizkitItem
            end
            connect SIGNAL("expanded(QModelIndex)") do |index|
                item_from_index(index).expanded
                item = item_from_index(index.sibling(index.row,1))
                item.expanded if item.is_a? VizkitItem
            end
        end

        def tree_view.disconnected_items
            @disconnected_items ||= []
        end

        # stops all listeners
        # this should be called if the tree view is no longer visible
        #
        # warning: if the tree view is still visible it will reconnect
        # if a item gets expanded
        def tree_view.disconnect
            0.upto(real_model.rowCount-1) do |i|
                index = real_model.index(i,0)
                next unless isExpanded(model.is_a?(Qt::AbstractProxyModel) ? model.mapFromSource(index) : index)

                real_model.item(i,0).collapsed
                real_model.item(i,1).collapsed
                disconnected_items << i
            end
        end

        # restores the state before disconnect was called
        def tree_view.reconnect
            disconnected_items.each do |i|
                real_model.item(i,0).expand
                real_model.item(i,1).expand
            end
            disconnected_items.clear
        end
    end

    class TaskSortFilterProxyModel < Qt::SortFilterProxyModel
        def filterAcceptsRow(source_row, source_parent)
            source_index = sourceModel.index(source_row, 0, source_parent)
            return false unless source_index.isValid
            item = sourceModel.itemFromIndex(source_index)
            if item.is_a?(Vizkit::TaskContextItem) && !filterRegExp.pattern.nil?
                return item.task.basename.include? filterRegExp.pattern
            end
            return true
        end
    end

    # editor for enum values
    class EnumEditor < Qt::ComboBox
        def initialize(parent,data)
            super(parent)
            data.to_a.each do |val|
                addItem(val.to_s)
            end
        end
        # we cannot use user properties here
        # there is no way to define some on the ruby side
        def getData
            currentText
        end
    end

    # buttons for cancel or acknowledge a custom property change
    class AcknowledgeEditor < Qt::DialogButtonBox
        def initialize(parent,data,delegate)
            super(parent)
            addButton("Apply",Qt::DialogButtonBox::AcceptRole)
            addButton("Reject",Qt::DialogButtonBox::RejectRole)
            setCenterButtons(true)
            setAutoFillBackground(true)
            self.connect SIGNAL('rejected()') do
                data.modified!(false)
                deleteLater
                delegate.tree_view.model.layoutChanged
            end
            self.connect SIGNAL('accepted()') do
                data.write
                delegate.commitData(self)
                deleteLater
                delegate.tree_view.model.layoutChanged
            end
        end
    end

    # Delegate to select editor for editing tree view items
    class ItemDelegate < Qt::StyledItemDelegate
        attr_reader :tree_view
        def initialize(tree_view,parent = nil)
            super(parent)
            @tree_view = tree_view
        end

        def createEditor (parent, option,index)
            data = index.data(Qt::EditRole)
            if data.type == Qt::Variant::StringList
                Vizkit::EnumEditor.new(parent,data)
            elsif data.to_ruby?
                model = data.to_ruby
                Vizkit::AcknowledgeEditor.new(parent,model,self)
            else
                editor = super
                if editor.is_a? Qt::DoubleSpinBox
                    editor.setDecimals 10
                end
                editor
            end
        end

        def setModelData(editor,model,index)
            # we cannot use user properties here
            # there is no way to define some on the ruby side
            if editor.respond_to? :getData
                model.setData(index,Qt::Variant.new(editor.getData),Qt::EditRole)
            elsif editor.is_a? Qt::ComboBox
                model.setData(index,Qt::Variant.new(editor.currentText),Qt::EditRole)
            else
                super
            end

            # show reject and apply buttons if the parent has the options
            # :accept => true
            parent = index
            while (parent = parent.parent).isValid
                item = @tree_view.item_from_index(parent)
                if !!item.options[:accept] && item.modified?
                    parent = parent.sibling(parent.row,1)
                    break unless parent.isValid
                    @tree_view.setCurrentIndex(parent)
                    @tree_view.openPersistentEditor(parent)
                    break
                end
            end
        end
    end

    class VizkitItemModel < Qt::StandardItemModel
        def initialize(*args)
            super
            setColumnCount 2
            setHorizontalHeaderLabels ["Name","Value"]
        end

        def mimeData(indexes)
            return 0 if indexes.empty? || !indexes.first.valid?
            item = itemFromIndex(indexes.first)
            return item.mime_data if item
            0
        end

        def mimeTypes
            ["text/plain"]
        end
    end
end
