#ifndef TRAJECTORYVISUALISATION_H
#define TRAJECTORYVISUALISATION_H
#include <Eigen/Geometry>
#include <list>
#include <osg/Geometry>
#include <vizkit/Vizkit3DPlugin.hpp>
#include <base/geometry/spline.h>

namespace vizkit 
{

class TrajectoryVisualization: public Vizkit3DPlugin<base::Vector3d>, public VizPluginAddType<base::geometry::Spline3>
{
    Q_OBJECT
    //unsigned int is not supported by the property browser so far
    Q_PROPERTY(int MaxPoints READ getMaxNumberOfPoints WRITE setMaxNumberOfPoints)

    public:
	TrajectoryVisualization();
        ~TrajectoryVisualization();
        void setColor(const base::Vector3d& color); 
	void setColor(double r, double g, double b, double a);
	Q_INVOKABLE void clear();
        
        Q_INVOKABLE void updateData(const base::geometry::Spline<3>& data)
        { Vizkit3DPlugin<base::Vector3d>::updateData(data); }
        Q_INVOKABLE void updateSpline(const base::geometry::Spline<3>& data)
        { updateData(data); }
        Q_INVOKABLE void updateData(const base::Vector3d& data)
        { Vizkit3DPlugin<base::Vector3d>::updateData(data); }
        Q_INVOKABLE void updateTrajectory(const base::Vector3d& data)
        { updateData(data); }

    public slots:
        int getMaxNumberOfPoints(){return max_number_of_points;};
        void setMaxNumberOfPoints(int points){max_number_of_points = points;};

    protected:
	virtual osg::ref_ptr<osg::Node> createMainNode();
	virtual void updateMainNode( osg::Node* node );
	void updateDataIntern( const  base::Vector3d& data );
	void updateDataIntern(const base::geometry::Spline3& data);
	
    private:
	osg::Vec4Array *color2; 
	bool doClear;
        int max_number_of_points;

	std::list<Eigen::Vector3d> points;
	osg::ref_ptr<osg::Vec3Array> pointsOSG;
	osg::ref_ptr<osg::DrawArrays> drawArrays;
	osg::ref_ptr<osg::Geometry> geom;
};

}
#endif // TRAJECTORYVISUALISATION_H
